import Foundation
import Observation

enum PedalboardPlaybackError: Equatable, LocalizedError, Sendable {
    case resolutionFailed(entryID: PedalboardEntry.ID, index: Int, detail: String)
    case invalidSequence(entryID: PedalboardEntry.ID, index: Int, detail: String)
    case startFailed(entryID: PedalboardEntry.ID, index: Int, detail: String)
    case audioInterrupted
    case engineFailure

    var errorDescription: String? {
        switch self {
        case .resolutionFailed(_, let index, let detail):
            "Could not load pedalboard entry \(index + 1): \(detail)"
        case .invalidSequence(_, let index, let detail):
            "Pedalboard entry \(index + 1) has an invalid sequence: \(detail)"
        case .startFailed(_, let index, let detail):
            "Could not start pedalboard entry \(index + 1): \(detail)"
        case .audioInterrupted:
            "Audio playback was interrupted."
        case .engineFailure:
            "Audio playback stopped unexpectedly."
        }
    }
}

enum PedalboardPlaybackState: Equatable, Sendable {
    case idle
    case preparing(boardID: Pedalboard.ID)
    case playing(boardID: Pedalboard.ID, entryID: PedalboardEntry.ID, index: Int, total: Int)
    case stopping
    case finished(boardID: Pedalboard.ID)
    case failed(boardID: Pedalboard.ID?, error: PedalboardPlaybackError)

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }
}

enum PedalboardEntryPlaybackStatus: Equatable, Sendable {
    case playable
    case missing
}

struct PedalboardEntryPlaybackInfo: Equatable, Sendable {
    let entryID: PedalboardEntry.ID
    let pedalID: StoredPedal.ID
    let index: Int
    let status: PedalboardEntryPlaybackStatus
}

enum PedalboardEntryResolution: Equatable, Sendable {
    case resolved(PhotoPedal)
    case missing
}

protocol PedalboardEntryResolving {
    func resolvePedal(for entry: PedalboardEntry) throws -> PedalboardEntryResolution
}

struct PedalStorePedalboardEntryResolver: PedalboardEntryResolving {
    private let store: PedalStore

    init(store: PedalStore = .shared) {
        self.store = store
    }

    func resolvePedal(for entry: PedalboardEntry) throws -> PedalboardEntryResolution {
        do {
            return .resolved(try store.loadPhotoPedal(id: entry.pedalID))
        } catch PedalStoreError.missingRecord {
            return .missing
        } catch {
            throw error
        }
    }
}

@MainActor
protocol PedalboardPlaybackCancellation: AnyObject {
    func cancel()
}

@MainActor
protocol PedalboardPlaybackScheduling: AnyObject {
    func schedule(after duration: TimeInterval, _ action: @escaping @MainActor () -> Void) -> PedalboardPlaybackCancellation
}

@MainActor
final class ContinuousPedalboardPlaybackScheduler: PedalboardPlaybackScheduling {
    func schedule(after duration: TimeInterval, _ action: @escaping @MainActor () -> Void) -> PedalboardPlaybackCancellation {
        let nanoseconds = UInt64(max(0, duration) * 1_000_000_000)
        let task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                action()
            } catch { }
        }
        return PedalboardPlaybackTaskCancellation(task: task)
    }
}

@MainActor
private final class PedalboardPlaybackTaskCancellation: PedalboardPlaybackCancellation {
    private var task: Task<Void, Never>?

    init(task: Task<Void, Never>) {
        self.task = task
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

@MainActor
@Observable
final class PedalboardPlaybackCoordinator {
    private struct PlayableEntry: Equatable {
        let entry: PedalboardEntry
        let index: Int
        let pedal: PhotoPedal
        let duration: TimeInterval
    }

    private(set) var state: PedalboardPlaybackState = .idle
    private(set) var entryPlaybackInfo: [PedalboardEntryPlaybackInfo] = []

    private let resolver: any PedalboardEntryResolving
    private let player: any PedalPlaying
    private let scheduler: any PedalboardPlaybackScheduling
    private let sampleRate: Double
    private var generation = UUID()
    private var pendingCompletion: PedalboardPlaybackCancellation?
    private var currentBoardID: Pedalboard.ID?
    private var playableEntries: [PlayableEntry] = []
    private var isStartingPlayer = false

    convenience init() {
        self.init(
            resolver: PedalStorePedalboardEntryResolver(),
            player: PhotoPedalSynth(),
            scheduler: ContinuousPedalboardPlaybackScheduler()
        )
    }

    init(
        resolver: any PedalboardEntryResolving,
        player: any PedalPlaying,
        scheduler: any PedalboardPlaybackScheduling,
        sampleRate: Double = 44_100
    ) {
        self.resolver = resolver
        self.player = player
        self.scheduler = scheduler
        self.sampleRate = sampleRate
        self.player.stopHandler = { [weak self] reason in
            self?.handlePlayerStop(reason)
        }
    }

    func play(board: Pedalboard) {
        let token = resetSession(boardID: board.id, stoppingCurrentPlayback: state.isPlaying || player.isPlaying)
        state = .preparing(boardID: board.id)

        let total = board.entries.count
        guard total > 0 else {
            finish(boardID: board.id, token: token)
            return
        }

        var prepared: [PlayableEntry] = []
        var info: [PedalboardEntryPlaybackInfo] = []
        for (index, entry) in board.entries.enumerated() {
            do {
                switch try resolver.resolvePedal(for: entry) {
                case .missing:
                    info.append(PedalboardEntryPlaybackInfo(entryID: entry.id, pedalID: entry.pedalID, index: index, status: .missing))
                case .resolved(let pedal):
                    guard pedal.id == entry.pedalID else {
                        fail(boardID: board.id, token: token, error: .resolutionFailed(entryID: entry.id, index: index, detail: "pedal id mismatch"))
                        return
                    }
                    let duration = try PedalPlaybackTiming.duration(sequence: pedal.sequence, sampleRate: sampleRate)
                    info.append(PedalboardEntryPlaybackInfo(entryID: entry.id, pedalID: entry.pedalID, index: index, status: .playable))
                    prepared.append(PlayableEntry(entry: entry, index: index, pedal: pedal, duration: duration))
                }
            } catch let error as PedalPlaybackTimingError {
                fail(boardID: board.id, token: token, error: .invalidSequence(entryID: entry.id, index: index, detail: error.localizedDescription))
                return
            } catch {
                fail(boardID: board.id, token: token, error: .resolutionFailed(entryID: entry.id, index: index, detail: error.localizedDescription))
                return
            }
        }

        entryPlaybackInfo = info
        playableEntries = prepared
        guard !prepared.isEmpty else {
            finish(boardID: board.id, token: token)
            return
        }
        playPreparedEntry(at: 0, boardID: board.id, total: total, token: token)
    }

    func stop() {
        generation = UUID()
        currentBoardID = nil
        playableEntries = []
        pendingCompletion?.cancel()
        pendingCompletion = nil
        isStartingPlayer = false
        if state.isPlaying || player.isPlaying {
            state = .stopping
            player.stop()
        }
        state = .idle
    }

    private func resetSession(boardID: Pedalboard.ID, stoppingCurrentPlayback: Bool) -> UUID {
        let token = UUID()
        generation = token
        currentBoardID = boardID
        playableEntries = []
        entryPlaybackInfo = []
        pendingCompletion?.cancel()
        pendingCompletion = nil
        isStartingPlayer = false
        if stoppingCurrentPlayback {
            state = .stopping
            player.stop()
        }
        return token
    }

    private func playPreparedEntry(at playableIndex: Int, boardID: Pedalboard.ID, total: Int, token: UUID) {
        guard generation == token, playableEntries.indices.contains(playableIndex) else { return }
        let item = playableEntries[playableIndex]
        state = .playing(boardID: boardID, entryID: item.entry.id, index: item.index, total: total)
        do {
            isStartingPlayer = true
            defer { isStartingPlayer = false }
            try player.play(item.pedal)
        } catch {
            fail(boardID: boardID, token: token, error: .startFailed(entryID: item.entry.id, index: item.index, detail: error.localizedDescription))
            return
        }
        pendingCompletion = scheduler.schedule(after: item.duration) { [weak self] in
            self?.completePreparedEntry(at: playableIndex, boardID: boardID, total: total, token: token)
        }
    }

    private func completePreparedEntry(at playableIndex: Int, boardID: Pedalboard.ID, total: Int, token: UUID) {
        guard generation == token else { return }
        pendingCompletion?.cancel()
        pendingCompletion = nil
        let nextIndex = playableIndex + 1
        if playableEntries.indices.contains(nextIndex) {
            playPreparedEntry(at: nextIndex, boardID: boardID, total: total, token: token)
        } else {
            finish(boardID: boardID, token: token)
        }
    }

    private func finish(boardID: Pedalboard.ID, token: UUID) {
        guard generation == token else { return }
        pendingCompletion?.cancel()
        pendingCompletion = nil
        playableEntries = []
        currentBoardID = nil
        if player.isPlaying { player.stop() }
        state = .finished(boardID: boardID)
    }

    private func fail(boardID: Pedalboard.ID?, token: UUID, error: PedalboardPlaybackError) {
        guard generation == token else { return }
        generation = UUID()
        pendingCompletion?.cancel()
        pendingCompletion = nil
        isStartingPlayer = false
        playableEntries = []
        currentBoardID = nil
        if player.isPlaying { player.stop() }
        state = .failed(boardID: boardID, error: error)
    }

    private func handlePlayerStop(_ reason: PhotoPedalSynthStopReason) {
        guard reason != .requested else { return }
        guard !isStartingPlayer else { return }
        let boardID = currentBoardID
        let token = generation
        switch reason {
        case .requested:
            return
        case .interruption:
            fail(boardID: boardID, token: token, error: .audioInterrupted)
        case .engineFailure:
            fail(boardID: boardID, token: token, error: .engineFailure)
        }
    }
}

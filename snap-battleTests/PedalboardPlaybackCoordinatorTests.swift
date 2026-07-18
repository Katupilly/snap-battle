import Foundation
import Testing
@testable import snap_battle

@MainActor
struct PedalboardPlaybackCoordinatorTests {
    @Test func emptyBoardFinishesWithoutStartingAudio() {
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(player: player)
        let board = Pedalboard(id: UUID(), name: "Empty", createdAt: .fixture, entries: [])

        coordinator.play(board: board)

        #expect(coordinator.state == .finished(boardID: board.id))
        #expect(player.playedIDs.isEmpty)
    }

    @Test func oneValidEntryPlaysAndFinishes() {
        let pedal = Self.pedal(id: UUID())
        let entry = PedalboardEntry(id: UUID(), pedalID: pedal.id)
        let board = Self.board(entries: [entry])
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], player: player, scheduler: scheduler)

        coordinator.play(board: board)

        #expect(coordinator.state == .playing(boardID: board.id, entryID: entry.id, index: 0, total: 1))
        #expect(player.playedIDs == [pedal.id])

        scheduler.completeNext()

        #expect(coordinator.state == .finished(boardID: board.id))
        #expect(player.stopCount == 1)
    }

    @Test func multipleEntriesPlayInOriginalOrder() {
        let first = Self.pedal(id: UUID())
        let second = Self.pedal(id: UUID())
        let firstEntry = PedalboardEntry(id: UUID(), pedalID: first.id)
        let secondEntry = PedalboardEntry(id: UUID(), pedalID: second.id)
        let board = Self.board(entries: [firstEntry, secondEntry])
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [first.id: .resolved(first), second.id: .resolved(second)], player: player, scheduler: scheduler)

        coordinator.play(board: board)
        scheduler.completeNext()

        #expect(player.playedIDs == [first.id, second.id])
        #expect(coordinator.state == .playing(boardID: board.id, entryID: secondEntry.id, index: 1, total: 2))

        scheduler.completeNext()

        #expect(coordinator.state == .finished(boardID: board.id))
    }

    @Test func duplicatePedalIDPlaysForEachEntryPosition() {
        let pedal = Self.pedal(id: UUID())
        let firstEntry = PedalboardEntry(id: UUID(), pedalID: pedal.id)
        let secondEntry = PedalboardEntry(id: UUID(), pedalID: pedal.id)
        let board = Self.board(entries: [firstEntry, secondEntry])
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], player: player, scheduler: scheduler)

        coordinator.play(board: board)
        scheduler.completeNext()

        #expect(player.playedIDs == [pedal.id, pedal.id])
        #expect(coordinator.state == .playing(boardID: board.id, entryID: secondEntry.id, index: 1, total: 2))
    }

    @Test func missingEntryBetweenValidEntriesIsSkippedWithoutMutatingBoard() {
        let first = Self.pedal(id: UUID())
        let missingID = UUID()
        let second = Self.pedal(id: UUID())
        let firstEntry = PedalboardEntry(id: UUID(), pedalID: first.id)
        let missingEntry = PedalboardEntry(id: UUID(), pedalID: missingID)
        let secondEntry = PedalboardEntry(id: UUID(), pedalID: second.id)
        let board = Self.board(entries: [firstEntry, missingEntry, secondEntry])
        let original = board
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [first.id: .resolved(first), missingID: .missing, second.id: .resolved(second)], player: player, scheduler: scheduler)

        coordinator.play(board: board)
        scheduler.completeNext()

        #expect(board == original)
        #expect(player.playedIDs == [first.id, second.id])
        #expect(coordinator.state == .playing(boardID: board.id, entryID: secondEntry.id, index: 2, total: 3))
        #expect(coordinator.entryPlaybackInfo == [
            PedalboardEntryPlaybackInfo(entryID: firstEntry.id, pedalID: first.id, index: 0, status: .playable),
            PedalboardEntryPlaybackInfo(entryID: missingEntry.id, pedalID: missingID, index: 1, status: .missing),
            PedalboardEntryPlaybackInfo(entryID: secondEntry.id, pedalID: second.id, index: 2, status: .playable)
        ])
    }

    @Test func allMissingEntriesFinishWithoutStartingAudio() {
        let firstEntry = PedalboardEntry(id: UUID(), pedalID: UUID())
        let secondEntry = PedalboardEntry(id: UUID(), pedalID: UUID())
        let board = Self.board(entries: [firstEntry, secondEntry])
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [firstEntry.pedalID: .missing, secondEntry.pedalID: .missing], player: player)

        coordinator.play(board: board)

        #expect(coordinator.state == .finished(boardID: board.id))
        #expect(player.playedIDs.isEmpty)
    }

    @Test func restartStopsCurrentPlaybackAndIgnoresStaleCompletion() {
        let first = Self.pedal(id: UUID())
        let second = Self.pedal(id: UUID())
        let firstBoard = Self.board(entries: [PedalboardEntry(id: UUID(), pedalID: first.id)])
        let secondEntry = PedalboardEntry(id: UUID(), pedalID: second.id)
        let secondBoard = Self.board(entries: [secondEntry])
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [first.id: .resolved(first), second.id: .resolved(second)], player: player, scheduler: scheduler)

        coordinator.play(board: firstBoard)
        coordinator.play(board: secondBoard)
        scheduler.completeOldest()

        #expect(player.stopCount == 1)
        #expect(player.playedIDs == [first.id, second.id])
        #expect(coordinator.state == .playing(boardID: secondBoard.id, entryID: secondEntry.id, index: 0, total: 1))
    }

    @Test func stopDuringPlaybackIsIdempotentAndStaleCompletionDoesNotAdvance() {
        let first = Self.pedal(id: UUID())
        let second = Self.pedal(id: UUID())
        let firstEntry = PedalboardEntry(id: UUID(), pedalID: first.id)
        let secondEntry = PedalboardEntry(id: UUID(), pedalID: second.id)
        let board = Self.board(entries: [firstEntry, secondEntry])
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [first.id: .resolved(first), second.id: .resolved(second)], player: player, scheduler: scheduler)

        coordinator.play(board: board)
        coordinator.stop()
        coordinator.stop()
        scheduler.completeCancelled()

        #expect(coordinator.state == .idle)
        #expect(player.playedIDs == [first.id])
        #expect(!player.playedIDs.contains(second.id))
    }

    @Test func stopAfterFinishedReturnsToIdle() {
        let pedal = Self.pedal(id: UUID())
        let board = Self.board(entries: [PedalboardEntry(id: UUID(), pedalID: pedal.id)])
        let scheduler = ManualPlaybackScheduler()
        let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], scheduler: scheduler)

        coordinator.play(board: board)
        scheduler.completeNext()
        coordinator.stop()

        #expect(coordinator.state == .idle)
    }

    @Test func lateRequestedStopCallbackDoesNotFailOrAdvance() {
        let pedal = Self.pedal(id: UUID())
        let board = Self.board(entries: [PedalboardEntry(id: UUID(), pedalID: pedal.id)])
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], player: player)

        coordinator.play(board: board)
        coordinator.stop()
        player.emit(.requested)

        #expect(coordinator.state == .idle)
    }

    @Test func synthStartFailureFailsAndDoesNotStayPlaying() {
        let pedal = Self.pedal(id: UUID())
        let entry = PedalboardEntry(id: UUID(), pedalID: pedal.id)
        let board = Self.board(entries: [entry])
        let player = PlaybackPlayerDouble(failOnPlayNumbers: [1], emitsStopReasonOnFailure: .engineFailure)
        let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], player: player)

        coordinator.play(board: board)

        #expect(coordinator.state == .failed(boardID: board.id, error: .startFailed(entryID: entry.id, index: 0, detail: PlaybackPlayerDouble.playbackError.localizedDescription)))
        #expect(!player.isPlaying)
    }

    @Test func synthFailureInMiddleFailsBoardAndStopsFutureProgression() {
        let first = Self.pedal(id: UUID())
        let second = Self.pedal(id: UUID())
        let firstEntry = PedalboardEntry(id: UUID(), pedalID: first.id)
        let secondEntry = PedalboardEntry(id: UUID(), pedalID: second.id)
        let board = Self.board(entries: [firstEntry, secondEntry])
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble(failOnPlayNumbers: [2])
        let coordinator = makeCoordinator(resolutions: [first.id: .resolved(first), second.id: .resolved(second)], player: player, scheduler: scheduler)

        coordinator.play(board: board)
        scheduler.completeNext()

        #expect(coordinator.state == .failed(boardID: board.id, error: .startFailed(entryID: secondEntry.id, index: 1, detail: PlaybackPlayerDouble.playbackError.localizedDescription)))
        #expect(player.playedIDs == [first.id])
    }

    @Test func resolverStructuralFailureFailsBoard() {
        let entry = PedalboardEntry(id: UUID(), pedalID: UUID())
        let board = Self.board(entries: [entry])
        let coordinator = makeCoordinator(resolutions: [entry.pedalID: .failure(ResolverDouble.resolutionError)])

        coordinator.play(board: board)

        #expect(coordinator.state == .failed(boardID: board.id, error: .resolutionFailed(entryID: entry.id, index: 0, detail: ResolverDouble.resolutionError.localizedDescription)))
    }

    @Test func invalidSequenceFailsBeforeStartingAudio() {
        let pedal = Self.pedal(id: UUID(), bpm: 0)
        let entry = PedalboardEntry(id: UUID(), pedalID: pedal.id)
        let board = Self.board(entries: [entry])
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], player: player)

        coordinator.play(board: board)

        #expect(coordinator.state == .failed(boardID: board.id, error: .invalidSequence(entryID: entry.id, index: 0, detail: PedalPlaybackTimingError.invalidBPM(0).localizedDescription)))
        #expect(player.playedIDs.isEmpty)
    }

    @Test func unexpectedInterruptionFailsActiveBoardButRequestedStopDoesNot() {
        let pedal = Self.pedal(id: UUID())
        let entry = PedalboardEntry(id: UUID(), pedalID: pedal.id)
        let board = Self.board(entries: [entry])
        let player = PlaybackPlayerDouble()
        let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], player: player)

        coordinator.play(board: board)
        player.emit(.interruption)

        #expect(coordinator.state == .failed(boardID: board.id, error: .audioInterrupted))
    }

    @Test func coordinatorDeallocationDoesNotRetainOrRunScheduledCallback() {
        let pedal = Self.pedal(id: UUID())
        let board = Self.board(entries: [PedalboardEntry(id: UUID(), pedalID: pedal.id)])
        let scheduler = ManualPlaybackScheduler()
        let player = PlaybackPlayerDouble()
        weak var weakCoordinator: PedalboardPlaybackCoordinator?

        do {
            let coordinator = makeCoordinator(resolutions: [pedal.id: .resolved(pedal)], player: player, scheduler: scheduler)
            weakCoordinator = coordinator
            coordinator.play(board: board)
        }

        #expect(weakCoordinator == nil)
        scheduler.completeNext()
        #expect(player.playedIDs == [pedal.id])
        #expect(player.stopHandler == nil)
    }

    @Test func sampleAlignedDurationUsesAllStepsOnly() throws {
        let pedal = Self.pedal(id: UUID(), bpm: 120, notes: [])

        let duration = try PedalPlaybackTiming.duration(sequence: pedal.sequence, sampleRate: 44_100)

        let expected = Double(max(1, Int(44_100 * 60 / Double(120) / 4)) * PedalSequence.steps) / 44_100
        #expect(duration == expected)
    }

    private func makeCoordinator(
        resolutions: [UUID: ResolverDouble.Result] = [:],
        player: PlaybackPlayerDouble? = nil,
        scheduler: ManualPlaybackScheduler? = nil
    ) -> PedalboardPlaybackCoordinator {
        PedalboardPlaybackCoordinator(
            resolver: ResolverDouble(resolutions: resolutions),
            player: player ?? PlaybackPlayerDouble(),
            scheduler: scheduler ?? ManualPlaybackScheduler()
        )
    }

    private static func board(entries: [PedalboardEntry]) -> Pedalboard {
        Pedalboard(id: UUID(), name: "Board", createdAt: .fixture, entries: entries)
    }

    private static func pedal(id: UUID, bpm: Int = 120, notes: [PedalNote] = [PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)]) -> PhotoPedal {
        PhotoPedal(
            id: id,
            name: "Pedal",
            description: "A test pedal.",
            sequence: PedalSequence(harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: bpm), notes: notes, soundProfile: .legacy),
            effect: .reverb,
            createdAt: .fixture,
            coverFilename: "\(id.uuidString).png"
        )
    }
}

private extension Date {
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
}

@MainActor
private final class ResolverDouble: PedalboardEntryResolving {
    enum Result {
        case resolved(PhotoPedal)
        case missing
        case failure(Error)
    }

    static let resolutionError = NSError(domain: "ResolverDouble", code: 7, userInfo: [NSLocalizedDescriptionKey: "Corrupt pedal JSON"])
    private let resolutions: [UUID: Result]

    init(resolutions: [UUID: Result]) {
        self.resolutions = resolutions
    }

    func resolvePedal(for entry: PedalboardEntry) throws -> PedalboardEntryResolution {
        switch resolutions[entry.pedalID] ?? .missing {
        case .resolved(let pedal):
            return .resolved(pedal)
        case .missing:
            return .missing
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
private final class PlaybackPlayerDouble: PedalPlaying {
    static let playbackError = NSError(domain: "PlaybackPlayerDouble", code: 9, userInfo: [NSLocalizedDescriptionKey: "Playback failed"])

    var stopHandler: ((PhotoPedalSynthStopReason) -> Void)?
    private(set) var isPlaying = false
    private(set) var playedIDs: [UUID] = []
    private(set) var stopCount = 0
    private var playCount = 0
    private let failOnPlayNumbers: Set<Int>
    private let emitsStopReasonOnFailure: PhotoPedalSynthStopReason?

    init(failOnPlayNumbers: Set<Int> = [], emitsStopReasonOnFailure: PhotoPedalSynthStopReason? = nil) {
        self.failOnPlayNumbers = failOnPlayNumbers
        self.emitsStopReasonOnFailure = emitsStopReasonOnFailure
    }

    func play(_ pedal: PhotoPedal) throws {
        playCount += 1
        if failOnPlayNumbers.contains(playCount) {
            isPlaying = false
            if let emitsStopReasonOnFailure { stopHandler?(emitsStopReasonOnFailure) }
            throw Self.playbackError
        }
        if isPlaying { stop() }
        playedIDs.append(pedal.id)
        isPlaying = true
    }

    func stop() {
        let wasPlaying = isPlaying
        stopCount += 1
        isPlaying = false
        if wasPlaying { stopHandler?(.requested) }
    }

    func emit(_ reason: PhotoPedalSynthStopReason) {
        isPlaying = false
        stopHandler?(reason)
    }
}

@MainActor
private final class ManualPlaybackScheduler: PedalboardPlaybackScheduling {
    private(set) var scheduledDurations: [TimeInterval] = []
    private var scheduled: [ManualCancellation] = []

    func schedule(after duration: TimeInterval, _ action: @escaping @MainActor () -> Void) -> PedalboardPlaybackCancellation {
        scheduledDurations.append(duration)
        let cancellation = ManualCancellation(action: action)
        scheduled.append(cancellation)
        return cancellation
    }

    func completeNext() {
        guard !scheduled.isEmpty else { return }
        let next = scheduled.removeFirst()
        next.complete()
    }

    func completeCancelled() {
        for item in scheduled { item.complete() }
        scheduled.removeAll()
    }

    func completeOldest() {
        guard !scheduled.isEmpty else { return }
        scheduled.removeFirst().complete()
    }
}

@MainActor
private final class ManualCancellation: PedalboardPlaybackCancellation {
    private var action: (@MainActor () -> Void)?
    private var isCancelled = false

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func cancel() {
        isCancelled = true
    }

    func complete() {
        guard !isCancelled else { return }
        action?()
        action = nil
    }
}

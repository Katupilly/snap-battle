import Foundation
import Observation
import UIKit

protocol PedalboardStoring {
    func loadCollection() -> PedalboardStoreLoadResult
    func load(id: UUID) throws -> Pedalboard
    func save(_ board: Pedalboard) throws
}

extension PedalboardStore: PedalboardStoring {}

protocol PedalLibraryLoading {
    func loadPedals() -> PedalStoreLoadResult
    func thumbnailAsset(for id: UUID) -> PersistedImageAsset?
}

extension PedalStore: PedalLibraryLoading {
    func loadPedals() -> PedalStoreLoadResult {
        loadCollection()
    }
}

@MainActor
protocol PedalboardPlaybackControlling: AnyObject {
    var state: PedalboardPlaybackState { get }
    func play(board: Pedalboard)
    func stop()
}

extension PedalboardPlaybackCoordinator: PedalboardPlaybackControlling {}

enum PedalboardsViewState: Equatable {
    case loading
    case empty
    case content([Pedalboard])
    case partialError([Pedalboard], String)
    case blockingError(String)

    var boards: [Pedalboard] {
        switch self {
        case .content(let boards), .partialError(let boards, _):
            boards
        case .loading, .empty, .blockingError:
            []
        }
    }
}

enum PedalboardEntryDisplayStatus: Equatable {
    case available(StoredPedal)
    case missing

    static func == (lhs: PedalboardEntryDisplayStatus, rhs: PedalboardEntryDisplayStatus) -> Bool {
        switch (lhs, rhs) {
        case (.missing, .missing):
            true
        case (.available(let left), .available(let right)):
            left.id == right.id
        case (.missing, .available), (.available, .missing):
            false
        }
    }
}

struct PedalboardEntryDisplay: Identifiable, Equatable {
    let id: PedalboardEntry.ID
    let entry: PedalboardEntry
    let index: Int
    let status: PedalboardEntryDisplayStatus

    var pedalID: StoredPedal.ID { entry.pedalID }
}

@MainActor
@Observable
final class PedalboardsViewModel {
    var state: PedalboardsViewState = .loading
    var selectedBoard: Pedalboard?
    var entryDisplays: [PedalboardEntryDisplay] = []
    var availablePedals: [StoredPedal] = []
    var errorMessage: String?
    var playbackErrorMessage: String?
    private(set) var isCreatingBoard = false
    private(set) var isSavingBoard = false
    let playbackCoordinator: PedalboardPlaybackCoordinator?

    private let boardStore: any PedalboardStoring
    private let pedalStore: any PedalLibraryLoading
    private let playback: any PedalboardPlaybackControlling
    private let now: () -> Date

    init(
        boardStore: any PedalboardStoring = PedalboardStore.shared,
        pedalStore: any PedalLibraryLoading = PedalStore.shared,
        now: @escaping () -> Date = Date.init
    ) {
        let coordinator = PedalboardPlaybackCoordinator()
        self.boardStore = boardStore
        self.pedalStore = pedalStore
        self.playback = coordinator
        self.playbackCoordinator = coordinator
        self.now = now
    }

    init(
        boardStore: any PedalboardStoring,
        pedalStore: any PedalLibraryLoading,
        playback: any PedalboardPlaybackControlling,
        now: @escaping () -> Date = Date.init
    ) {
        self.boardStore = boardStore
        self.pedalStore = pedalStore
        self.playback = playback
        self.playbackCoordinator = playback as? PedalboardPlaybackCoordinator
        self.now = now
    }

    var playbackState: PedalboardPlaybackState {
        playbackCoordinator?.state ?? playback.state
    }

    var activeEntryID: PedalboardEntry.ID? {
        guard let boardID = selectedBoard?.id else { return nil }
        if case .playing(let playingBoardID, let entryID, _, _) = playbackState, playingBoardID == boardID {
            return entryID
        }
        return nil
    }

    var isPlaybackBusy: Bool {
        switch playbackState {
        case .preparing, .playing, .stopping:
            true
        case .idle, .finished, .failed:
            false
        }
    }

    func reload() {
        state = .loading
        let result = boardStore.loadCollection()
        apply(result)
    }

    func reloadLibrary() {
        let result = pedalStore.loadPedals()
        availablePedals = result.pedals
        refreshEntryDisplays()
        errorMessage = result.issues.isEmpty ? nil : result.issues.joined(separator: " ")
    }

    /// Creates a new board and returns its ID. On success, keeps `isCreatingBoard`
    /// active until `openBoard(id:)` clears it. On failure, clears the flag immediately.
    /// Call sites must call `openBoard(id:)` after a successful creation.
    func createBoard() -> Pedalboard.ID? {
        guard !isCreatingBoard else { return nil }
        isCreatingBoard = true
        let board = PedalboardMutation.make(name: Pedalboard.defaultName, now: now())
        do {
            try boardStore.save(board)
            selectedBoard = board
            reload()
            return board.id
        } catch {
            errorMessage = error.localizedDescription
            isCreatingBoard = false
            return nil
        }
    }

    @discardableResult
    func openBoard(id: Pedalboard.ID) -> Bool {
        do {
            selectedBoard = try boardStore.load(id: id)
            reloadLibrary()
            refreshEntryDisplays()
            isCreatingBoard = false
            return true
        } catch {
            selectedBoard = nil
            entryDisplays = []
            errorMessage = error.localizedDescription
            isCreatingBoard = false
            reload()
            return false
        }
    }

    func closeBoard() {
        stop()
        selectedBoard = nil
        entryDisplays = []
    }

    func renameSelectedBoard(_ rawName: String) {
        guard let board = selectedBoard else { return }
        save(PedalboardMutation.rename(rawName, board: board, now: now()))
    }

    func addPedal(_ pedal: StoredPedal) {
        guard let board = selectedBoard else { return }
        stopIfPlaybackBusy()
        save(PedalboardMutation.addPedal(pedal.id, to: board, now: now()))
    }

    func removeEntry(id entryID: PedalboardEntry.ID) {
        guard let board = selectedBoard else { return }
        stopIfPlaybackBusy()
        save(PedalboardMutation.removeEntry(id: entryID, from: board, now: now()))
    }

    func moveEntry(id entryID: PedalboardEntry.ID, to destination: Int) {
        guard let board = selectedBoard,
              let updated = PedalboardMutation.moveEntry(id: entryID, to: destination, in: board, now: now()) else { return }
        stopIfPlaybackBusy()
        save(updated)
    }

    func moveEntries(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first,
              let entry = selectedBoard?.entries[safe: sourceIndex] else { return }
        let finalDestination = sourceIndex < destination ? destination - 1 : destination
        moveEntry(id: entry.id, to: finalDestination)
    }

    func play() {
        guard let board = selectedBoard, !isPlaybackBusy else { return }
        playbackErrorMessage = nil
        playback.play(board: board)
        if case .failed(_, let error) = playback.state {
            playbackErrorMessage = error.localizedDescription
        }
    }

    func stop() {
        playback.stop()
    }

    func updatePlaybackErrorMessage(from state: PedalboardPlaybackState) {
        if case .failed(_, let error) = state {
            playbackErrorMessage = error.localizedDescription
        }
    }

    func thumbnailAsset(for id: UUID) -> PersistedImageAsset? {
        pedalStore.thumbnailAsset(for: id)
    }

    private func apply(_ result: PedalboardStoreLoadResult) {
        if result.boards.isEmpty {
            state = result.issues.isEmpty ? .empty : .blockingError(result.issues.joined(separator: " "))
        } else {
            state = result.issues.isEmpty ? .content(result.boards) : .partialError(result.boards, result.issues.joined(separator: " "))
        }
    }

    private func save(_ board: Pedalboard) {
        guard selectedBoard != board else { return }
        isSavingBoard = true
        defer { isSavingBoard = false }
        do {
            try boardStore.save(board)
            selectedBoard = board
            reload()
            refreshEntryDisplays()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshEntryDisplays() {
        guard let board = selectedBoard else {
            entryDisplays = []
            return
        }
        let pedalsByID = Dictionary(uniqueKeysWithValues: availablePedals.map { ($0.id, $0) })
        entryDisplays = board.entries.enumerated().map { index, entry in
            PedalboardEntryDisplay(
                id: entry.id,
                entry: entry,
                index: index,
                status: pedalsByID[entry.pedalID].map(PedalboardEntryDisplayStatus.available) ?? .missing
            )
        }
    }

    private func stopIfPlaybackBusy() {
        if isPlaybackBusy {
            stop()
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

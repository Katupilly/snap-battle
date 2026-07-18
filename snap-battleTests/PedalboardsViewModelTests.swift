import Foundation
import Testing
import UIKit
@testable import snap_battle

@MainActor
struct PedalboardsViewModelTests {
    @Test func createBoardPersistsAndSelectsDefaultBoard() {
        let boardStore = BoardStoreDouble()
        let model = makeModel(boardStore: boardStore)

        let id = model.createBoard()

        #expect(id != nil)
        #expect(model.selectedBoard?.id == id)
        #expect(model.selectedBoard?.name == Pedalboard.defaultName)
        #expect(boardStore.savedBoards.map(\.id) == [id])
        #expect(model.state.boards.map(\.id) == [id])
    }

    @Test func renameUsesDomainNormalizationAndPersistsOnce() {
        let board = Self.board(name: "Old")
        let boardStore = BoardStoreDouble(boards: [board])
        let model = makeModel(boardStore: boardStore)
        #expect(model.openBoard(id: board.id))

        model.renameSelectedBoard("  New Name  ")

        #expect(model.selectedBoard?.name == "New Name")
        #expect(boardStore.savedBoards.last?.name == "New Name")
    }

    @Test func addPedalAllowsDuplicatesAndPersistsEntries() {
        let board = Self.board()
        let pedal = Self.storedPedal(name: "Kick")
        let boardStore = BoardStoreDouble(boards: [board])
        let model = makeModel(boardStore: boardStore, pedalStore: PedalStoreDouble(pedals: [pedal]))
        #expect(model.openBoard(id: board.id))

        model.addPedal(pedal)
        model.addPedal(pedal)

        #expect(model.selectedBoard?.entries.map(\.pedalID) == [pedal.id, pedal.id])
        #expect(Set(model.selectedBoard?.entries.map(\.id) ?? []).count == 2)
    }

    @Test func removeEntryUsesEntryIDNotPedalID() {
        let pedal = Self.storedPedal(name: "Duplicate")
        var board = Self.board()
        board = PedalboardMutation.addPedal(pedal.id, to: board, now: .fixture)
        board = PedalboardMutation.addPedal(pedal.id, to: board, now: .fixture)
        let secondEntryID = board.entries[1].id
        let boardStore = BoardStoreDouble(boards: [board])
        let model = makeModel(boardStore: boardStore, pedalStore: PedalStoreDouble(pedals: [pedal]))
        #expect(model.openBoard(id: board.id))

        model.removeEntry(id: secondEntryID)

        #expect(model.selectedBoard?.entries.count == 1)
        #expect(model.selectedBoard?.entries[0].id == board.entries[0].id)
    }

    @Test func reorderPersistsAndPlaybackOrderMatchesDisplayedOrder() {
        let first = Self.storedPedal(name: "First")
        let second = Self.storedPedal(name: "Second")
        var board = Self.board()
        board = PedalboardMutation.addPedal(first.id, to: board, now: .fixture)
        board = PedalboardMutation.addPedal(second.id, to: board, now: .fixture)
        let firstEntryID = board.entries[0].id
        let playback = PlaybackDouble()
        let model = makeModel(
            boardStore: BoardStoreDouble(boards: [board]),
            pedalStore: PedalStoreDouble(pedals: [first, second]),
            playback: playback
        )
        #expect(model.openBoard(id: board.id))

        model.moveEntry(id: firstEntryID, to: 1)
        model.play()

        #expect(model.entryDisplays.map(\.pedalID) == [second.id, first.id])
        #expect(playback.playedBoards.last?.entries.map(\.pedalID) == [second.id, first.id])
    }

    @Test func missingReferenceResolvesAsMissingDisplay() {
        let missingID = UUID()
        var board = Self.board()
        board = PedalboardMutation.addPedal(missingID, to: board, now: .fixture)
        let model = makeModel(boardStore: BoardStoreDouble(boards: [board]), pedalStore: PedalStoreDouble(pedals: []))

        #expect(model.openBoard(id: board.id))

        #expect(model.entryDisplays.count == 1)
        #expect(model.entryDisplays[0].status == .missing)
    }

    @Test func playIsIgnoredWhilePlaybackIsBusy() {
        let pedal = Self.storedPedal(name: "One")
        var board = Self.board()
        board = PedalboardMutation.addPedal(pedal.id, to: board, now: .fixture)
        let playback = PlaybackDouble()
        let model = makeModel(
            boardStore: BoardStoreDouble(boards: [board]),
            pedalStore: PedalStoreDouble(pedals: [pedal]),
            playback: playback
        )
        #expect(model.openBoard(id: board.id))

        model.play()
        model.play()

        #expect(playback.playedBoards.count == 1)
    }

    @Test func stopAndCloseBoardStopPlayback() {
        let pedal = Self.storedPedal(name: "One")
        var board = Self.board()
        board = PedalboardMutation.addPedal(pedal.id, to: board, now: .fixture)
        let playback = PlaybackDouble()
        let model = makeModel(
            boardStore: BoardStoreDouble(boards: [board]),
            pedalStore: PedalStoreDouble(pedals: [pedal]),
            playback: playback
        )
        #expect(model.openBoard(id: board.id))
        model.play()

        model.stop()
        model.play()
        model.closeBoard()

        #expect(playback.stopCount == 2)
        #expect(model.selectedBoard == nil)
    }

    @Test func mutatingBoardDuringPlaybackStopsBeforePersistingChange() {
        let first = Self.storedPedal(name: "First")
        let second = Self.storedPedal(name: "Second")
        var board = Self.board()
        board = PedalboardMutation.addPedal(first.id, to: board, now: .fixture)
        board = PedalboardMutation.addPedal(second.id, to: board, now: .fixture)
        let playback = PlaybackDouble()
        playback.state = .playing(boardID: board.id, entryID: board.entries[0].id, index: 0, total: 2)
        let boardStore = BoardStoreDouble(boards: [board])
        let model = makeModel(
            boardStore: boardStore,
            pedalStore: PedalStoreDouble(pedals: [first, second]),
            playback: playback
        )
        #expect(model.openBoard(id: board.id))

        model.moveEntry(id: board.entries[0].id, to: 1)

        #expect(playback.stopCount == 1)
        #expect(boardStore.savedBoards.last?.entries.map(\.id) == [board.entries[1].id, board.entries[0].id])
    }

    @Test func activeEntryTracksPlaybackStateForSelectedBoardOnly() {
        let pedal = Self.storedPedal(name: "One")
        var board = Self.board()
        board = PedalboardMutation.addPedal(pedal.id, to: board, now: .fixture)
        let entryID = board.entries[0].id
        let playback = PlaybackDouble()
        let model = makeModel(
            boardStore: BoardStoreDouble(boards: [board]),
            pedalStore: PedalStoreDouble(pedals: [pedal]),
            playback: playback
        )
        #expect(model.openBoard(id: board.id))

        playback.state = .playing(boardID: board.id, entryID: entryID, index: 0, total: 1)
        #expect(model.activeEntryID == entryID)

        playback.state = .playing(boardID: UUID(), entryID: entryID, index: 0, total: 1)
        #expect(model.activeEntryID == nil)
    }

    @Test func emptyBoardPlayFinishesThroughCoordinator() {
        let board = Self.board()
        let playback = PlaybackDouble()
        let model = makeModel(boardStore: BoardStoreDouble(boards: [board]), playback: playback)
        #expect(model.openBoard(id: board.id))

        model.play()

        #expect(playback.playedBoards.map(\.id) == [board.id])
    }

    @Test func playbackFailureStateUpdatesVisibleError() {
        let model = makeModel()

        model.updatePlaybackErrorMessage(from: .failed(boardID: nil, error: .engineFailure))

        #expect(model.playbackErrorMessage == PedalboardPlaybackError.engineFailure.localizedDescription)
    }

    @Test func saveGuardAllowsRenameToNewName() {
        let board = Self.board(name: "Old")
        let boardStore = BoardStoreDouble(boards: [board])
        let model = makeModel(boardStore: boardStore)
        #expect(model.openBoard(id: board.id))

        model.renameSelectedBoard("New")

        #expect(model.selectedBoard?.name == "New")
        #expect(boardStore.savedBoards.last?.name == "New")
    }

    @Test func saveGuardBlocksRenameToSameNormalized() {
        let board = Self.board(name: "Same")
        let boardStore = BoardStoreDouble(boards: [board])
        let model = makeModel(boardStore: boardStore)
        #expect(model.openBoard(id: board.id))
        let savesBefore = boardStore.savedBoards.count

        model.renameSelectedBoard("  Same  ")

        #expect(boardStore.savedBoards.count == savesBefore)
        #expect(model.selectedBoard?.name == "Same")
    }

    @Test func createBoardCalledTwiceRapidlySecondIsIgnored() {
        let boardStore = BoardStoreDouble()
        let model = makeModel(boardStore: boardStore)

        let first = model.createBoard()
        let second = model.createBoard()

        #expect(first != nil)
        #expect(second == nil)
        #expect(model.state.boards.count == 1)
    }

    @Test func createBoardResetsFlagAfterOpenBoard() {
        let boardStore = BoardStoreDouble()
        let model = makeModel(boardStore: boardStore)

        let id = model.createBoard()
        #expect(id != nil)

        #expect(model.openBoard(id: id!))

        let second = model.createBoard()
        #expect(second != nil)
        #expect(model.state.boards.count == 2)
    }

    @Test func playCloseBoardThenReopenAllowsNewPlayback() {
        let pedal = Self.storedPedal(name: "Lifecycle")
        var board = Self.board(name: "Lifecycle Board")
        board = PedalboardMutation.addPedal(pedal.id, to: board, now: .fixture)
        let playback = PlaybackDouble()
        let boardStore = BoardStoreDouble(boards: [board])
        let model = makeModel(
            boardStore: boardStore,
            pedalStore: PedalStoreDouble(pedals: [pedal]),
            playback: playback
        )
        #expect(model.openBoard(id: board.id))
        model.play()

        #expect(playback.playedBoards.count == 1)
        #expect(model.activeEntryID != nil || model.playbackState == .playing(boardID: board.id, entryID: board.entries[0].id, index: 0, total: 1))

        model.closeBoard()

        #expect(playback.stopCount == 1)
        #expect(model.selectedBoard == nil)
        #expect(model.entryDisplays.isEmpty)

        #expect(model.openBoard(id: board.id))
        model.play()

        #expect(playback.playedBoards.count == 2)
        #expect(playback.stopCount == 1)
    }

    @Test func closeBoardIsIdempotentWhenAlreadyClosed() {
        let model = makeModel()
        model.closeBoard()
        model.closeBoard()

        #expect(model.selectedBoard == nil)
        #expect(model.entryDisplays.isEmpty)
    }

    @Test func persistenceFailureLeavesBoardVisibleAndReportsError() {
        let board = Self.board()
        let pedal = Self.storedPedal(name: "One")
        let boardStore = BoardStoreDouble(boards: [board], saveError: CocoaError(.fileWriteNoPermission))
        let model = makeModel(boardStore: boardStore, pedalStore: PedalStoreDouble(pedals: [pedal]))
        #expect(model.openBoard(id: board.id))

        model.addPedal(pedal)

        #expect(model.selectedBoard == board)
        #expect(model.errorMessage != nil)
    }

    private func makeModel(
        boardStore: BoardStoreDouble? = nil,
        pedalStore: PedalStoreDouble? = nil,
        playback: PlaybackDouble? = nil
    ) -> PedalboardsViewModel {
        let boardStore = boardStore ?? BoardStoreDouble()
        let pedalStore = pedalStore ?? PedalStoreDouble()
        let playback = playback ?? PlaybackDouble()
        return PedalboardsViewModel(
            boardStore: boardStore,
            pedalStore: pedalStore,
            playback: playback,
            now: { .fixture }
        )
    }

    private static func board(name: String = "Board") -> Pedalboard {
        PedalboardMutation.make(name: name, now: .fixture)
    }

    private static func storedPedal(name: String) -> StoredPedal {
        let id = UUID()
        let pedal = PhotoPedal(
            id: id,
            name: name,
            description: "Test",
            sequence: PedalSequence(
                harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 120),
                notes: [],
                soundProfile: .legacy
            ),
            effect: .reverb,
            createdAt: .fixture,
            coverFilename: "\(id.uuidString).png"
        )
        return StoredPedal(pedal: pedal, cover: UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        })
    }
}

private final class BoardStoreDouble: PedalboardStoring {
    private var boardsByID: [UUID: Pedalboard]
    private let saveError: Error?
    private(set) var savedBoards: [Pedalboard] = []

    init(boards: [Pedalboard] = [], saveError: Error? = nil) {
        boardsByID = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, $0) })
        self.saveError = saveError
    }

    func loadCollection() -> PedalboardStoreLoadResult {
        PedalboardStoreLoadResult(boards: PedalboardStore.ordered(Array(boardsByID.values)), issues: [])
    }

    func load(id: UUID) throws -> Pedalboard {
        guard let board = boardsByID[id] else { throw PedalboardStoreError.missingRecord }
        return board
    }

    func save(_ board: Pedalboard) throws {
        if let saveError { throw saveError }
        boardsByID[board.id] = board
        savedBoards.append(board)
    }

}

private struct PedalStoreDouble: PedalLibraryLoading {
    var pedals: [StoredPedal] = []
    var issues: [String] = []

    func loadPedals() -> PedalStoreLoadResult {
        PedalStoreLoadResult(pedals: pedals, issues: issues)
    }

    func thumbnailAsset(for id: UUID) -> PersistedImageAsset? {
        nil
    }
}

@MainActor
private final class PlaybackDouble: PedalboardPlaybackControlling {
    var state: PedalboardPlaybackState = .idle
    private(set) var playedBoards: [Pedalboard] = []
    private(set) var stopCount = 0

    func play(board: Pedalboard) {
        playedBoards.append(board)
        if let entry = board.entries.first {
            state = .playing(boardID: board.id, entryID: entry.id, index: 0, total: board.entries.count)
        } else {
            state = .finished(boardID: board.id)
        }
    }

    func stop() {
        stopCount += 1
        state = .idle
    }
}

private extension Date {
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
}

import Foundation
import Testing
import UIKit
@testable import snap_battle

@MainActor
struct GalleryReloadInstrumentationTests {
    @Test func savePedalSequenceSchedulesExactlyOneGalleryReload() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = LoadCounter()
        let store = PedalStore(directory: directory, loadCollectionDidRun: counter.record)
        let model = GalleryViewModel(store: store, player: StubPlayer())
        let navigation = AppNavigationModel()

        await model.reloadAsync(reason: .initialLoad)
        counter.assert(equals: 1)

        navigation.beginCapture()
        navigation.completeCapture()
        model.insertedSavedPedal()

        await waitForIdleLoad(counter: counter, expected: 2)
        counter.assert(equals: 2)
    }

    @Test func captureCancellationDoesNotReloadGallery() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = LoadCounter()
        let store = PedalStore(directory: directory, loadCollectionDidRun: counter.record)
        let model = GalleryViewModel(store: store, player: StubPlayer())
        let navigation = AppNavigationModel()

        await model.reloadAsync(reason: .initialLoad)
        counter.assert(equals: 1)

        navigation.beginCapture()
        navigation.cancelCapture()
        navigation.beginCapture()
        navigation.cancelCapture()

        try await Task.sleep(for: .milliseconds(150))
        counter.assert(equals: 1)
    }

    @Test func openingAndReturningFromPedalDetailDoesNotReloadGallery() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = LoadCounter()
        let store = PedalStore(directory: directory, loadCollectionDidRun: counter.record)
        let item = pedal(name: "Saved")
        try store.save(item, cover: cover(.blue))
        let model = GalleryViewModel(store: store, player: StubPlayer())
        let navigation = AppNavigationModel()

        await model.reloadAsync(reason: .initialLoad)
        counter.assert(equals: 1)

        navigation.path = [.pedalDetail(item.id)]
        try await Task.sleep(for: .milliseconds(80))
        navigation.path.removeLast()

        try await Task.sleep(for: .milliseconds(80))
        counter.assert(equals: 1)
    }

    @Test func switchingSelectedRootDoesNotReloadGallery() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = LoadCounter()
        let store = PedalStore(directory: directory, loadCollectionDidRun: counter.record)
        let item = pedal(name: "Saved")
        try store.save(item, cover: cover(.blue))
        let model = GalleryViewModel(store: store, player: StubPlayer())
        let navigation = AppNavigationModel()

        await model.reloadAsync(reason: .initialLoad)
        counter.assert(equals: 1)

        navigation.selectedDestination = .jam
        navigation.selectedDestination = .gallery
        navigation.selectedDestination = .jam

        try await Task.sleep(for: .milliseconds(80))
        counter.assert(equals: 1)
    }

    @Test func fixtureInstallProducesExactlyOneGalleryReload() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = LoadCounter()
        let store = PedalStore(directory: directory, loadCollectionDidRun: counter.record)
        let model = GalleryViewModel(store: store, player: StubPlayer())

        model.reload(reason: .fixtureInstalled)

        counter.assert(equals: 1)
    }

    @Test func boardOpenProducesExactlyOneLibraryReload() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = LoadCounter()
        let store = PedalStore(directory: directory, loadCollectionDidRun: counter.record)
        let item = pedal(name: "ForBoard")
        try store.save(item, cover: cover(.blue))
        let boardStore = InMemoryBoardStore()
        let board = PedalboardMutation.make(name: "Board", now: Date())
        try boardStore.save(board)
        let model = PedalboardsViewModel(boardStore: boardStore, pedalStore: store)

        let opened = model.openBoard(id: board.id)

        #expect(opened)
        counter.assert(equals: 1)
    }

    @Test func reloadReasonsAreDistinctAndStable() {
        let rawValues = GalleryReloadReason.allCases.map(\.rawValue)
        let unique = Set(rawValues)
        #expect(unique.count == rawValues.count)
        #expect(GalleryReloadReason.allCases.contains(.initialLoad))
        #expect(GalleryReloadReason.allCases.contains(.saveCompleted))
        #expect(GalleryReloadReason.allCases.contains(.boardOpen))
        #expect(GalleryReloadReason.allCases.contains(.fixtureInstalled))
    }

    private func waitForIdleLoad(counter: LoadCounter, expected: Int) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while counter.value < expected && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func temporaryDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func cover(_ color: UIColor) -> UIImage { UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { color.setFill(); $0.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) } }
    private func pedal(name: String) -> PhotoPedal {
        PhotoPedal(
            id: UUID(),
            name: name,
            description: "Test",
            sequence: PedalSequence(harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100), notes: [], soundProfile: .legacy),
            effect: .reverb,
            createdAt: .now,
            coverFilename: "latest-pedal.png"
        )
    }
}

@MainActor
private final class LoadCounter {
    private(set) var value = 0
    private let lock = NSLock()

    func record() {
        lock.lock(); defer { lock.unlock() }
        value += 1
    }

    func assert(equals expected: Int) {
        #expect(value == expected, "expected \(expected) galleryReload calls, observed \(value)")
    }
}

@MainActor
private final class StubPlayer: PedalPlaying {
    var stopHandler: ((PhotoPedalSynthStopReason) -> Void)?
    var isPlaying: Bool = false
    func play(_ pedal: PhotoPedal) throws { isPlaying = true }
    func stop() { isPlaying = false }
}

private final class InMemoryBoardStore: PedalboardStoring {
    private var boardsByID: [UUID: Pedalboard] = [:]

    func loadCollection() -> PedalboardStoreLoadResult {
        PedalboardStoreLoadResult(boards: Array(boardsByID.values), issues: [])
    }

    func load(id: UUID) throws -> Pedalboard {
        guard let board = boardsByID[id] else { throw PedalboardStoreError.missingRecord }
        return board
    }

    func save(_ board: Pedalboard) throws {
        boardsByID[board.id] = board
    }
}
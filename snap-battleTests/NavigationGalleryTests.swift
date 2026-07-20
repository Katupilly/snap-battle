import Foundation
import Testing
import UIKit
@testable import snap_battle

@MainActor
struct NavigationGalleryTests {
    @Test func collectionOrdersByDateThenUUIDAndLoadsByID() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let date = Date(timeIntervalSince1970: 10)
        let first = pedal(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Second", date: date)
        let second = pedal(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "First", date: date)
        try store.save(first, cover: cover(.blue))
        try store.save(second, cover: cover(.orange))

        let result = store.loadCollection()
        #expect(result.pedals.map(\.id) == [second.id, first.id])
        #expect(try store.load(id: first.id).pedal == first)
    }

    @Test func collectionIgnoresCorruptPairAndMigratesLegacyOnlyOnce() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = pedal(name: "Legacy")
        try JSONEncoder().encode(legacy).write(to: directory.appendingPathComponent("latest-pedal.json"))
        try png(cover(.blue)).write(to: directory.appendingPathComponent("latest-pedal.png"))
        let store = PedalStore(directory: directory)

        #expect(store.loadCollection().pedals.map(\.id) == [legacy.id])
        #expect(store.loadCollection().pedals.map(\.id) == [legacy.id])
        let collection = directory.appendingPathComponent("pedals")
        try Data("invalid".utf8).write(to: collection.appendingPathComponent("00000000-0000-0000-0000-000000000099.json"))
        #expect(store.loadCollection().hasPartialError)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("latest-pedal.json").path))
    }

    @Test func deletingMigratedLegacyDoesNotRecreateIt() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = pedal(name: "MONITOR")
        let legacyJSON = directory.appendingPathComponent("latest-pedal.json")
        let legacyPNG = directory.appendingPathComponent("latest-pedal.png")
        try JSONEncoder().encode(legacy).write(to: legacyJSON)
        try png(cover(.blue)).write(to: legacyPNG)
        let store = PedalStore(directory: directory)

        #expect(store.loadCollection().pedals.map(\.id) == [legacy.id])
        try store.delete(id: legacy.id)

        #expect(throws: Error.self) { try store.load(id: legacy.id) }
        #expect(store.loadCollection().pedals.isEmpty)
        #expect(store.loadLatest() == nil)
        #expect(FileManager.default.fileExists(atPath: legacyJSON.path))
        #expect(FileManager.default.fileExists(atPath: legacyPNG.path))
    }

    @Test func writeFailureDoesNotCreateVisibleRecord() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory, writeData: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        #expect(throws: Error.self) { try store.save(pedal(name: "Fail"), cover: cover(.red)) }
        #expect(store.loadCollection().pedals.isEmpty)
    }

    @Test func deleteNewestMakesNextPedalLatest() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let older = pedal(name: "Older", date: Date(timeIntervalSince1970: 1))
        let newer = pedal(name: "Newer", date: Date(timeIntervalSince1970: 2))
        try store.save(older, cover: cover(.blue)); try store.save(newer, cover: cover(.orange))
        try store.delete(id: newer.id)
        #expect(store.loadLatest()?.pedal.id == older.id)
    }

    @Test func loadingLibraryDoesNotRegeneratePersistedCovers() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let pedal = self.pedal(name: "Stored")
        let cover = self.cover(.blue)
        try store.save(pedal, cover: cover)

        let coverURL = directory
            .appendingPathComponent("pedals", isDirectory: true)
            .appendingPathComponent("\(pedal.id.uuidString).png")
        let beforeBytes = try Data(contentsOf: coverURL)
        let beforeDate = try FileManager.default.attributesOfItem(atPath: coverURL.path)[.modificationDate] as? Date

        _ = store.loadCollection(reason: "test-no-regeneration")
        let afterBytes = try Data(contentsOf: coverURL)
        let afterDate = try FileManager.default.attributesOfItem(atPath: coverURL.path)[.modificationDate] as? Date

        #expect(beforeBytes == afterBytes)
        #expect(beforeDate == afterDate)
    }

    @Test func navigationKeepsCaptureTransientAndCompletesInGallery() {
        let navigation = AppNavigationModel()
        #expect(navigation.selectedDestination == .gallery)
        navigation.selectedDestination = .jam
        navigation.beginCapture()
        #expect(navigation.isPresentingCapture)
        navigation.cancelCapture()
        #expect(navigation.selectedDestination == .jam)
        navigation.beginCapture()
        navigation.completeCapture()
        #expect(navigation.selectedDestination == .gallery)
        #expect(!navigation.isPresentingCapture)
    }

    @Test func nativeRootTabsIncludeOnlyGalleryAndJamDestinations() {
        let navigation = AppNavigationModel()
        let root = navigation.rootNavigation

        #expect(RootNavigationState.destinations == [.gallery, .jam])
        #expect(root.selectedDestination == .gallery)
        #expect(root.visibility == .visible)
        #expect(RootDestination(.jam) == .jam)
        #expect(RootNavigationState.destinations.map(\.accessibilityIdentifier) == ["bottomBar.destination.gallery", "bottomBar.destination.jam"])
    }

    @Test func tabSelectionUsesAppNavigationModelAsSingleSource() {
        let navigation = AppNavigationModel()
        #expect(navigation.selectedDestination == .gallery)

        navigation.selectedDestination = .jam
        #expect(navigation.rootNavigation.selectedDestination == .jam)

        navigation.selectedDestination = .gallery
        #expect(navigation.rootNavigation.selectedDestination == .gallery)
        #expect(RootNavigationState.destinations.map(\.appDestination) == [.gallery, .jam])
    }

    @Test func captureIsNotAPersistentTabDestination() {
        #expect(RootNavigationState.destinations == [.gallery, .jam])
        #expect(RootNavigationState.destinations.map(\.appDestination).contains(.gallery))
        #expect(RootNavigationState.destinations.map(\.appDestination).contains(.jam))
    }

    @Test func detailRoutesHideRootNavigationWithoutChangingSelection() {
        // Photo Inspector: tab bar and Capture disappear together;
        // on return both reappear with Gallery and its state intact.
        let navigation = AppNavigationModel()
        let pedalID = UUID()
        navigation.path = [.pedalDetail(pedalID)]

        #expect(navigation.rootNavigation.visibility == .hidden)
        #expect(navigation.selectedDestination == .gallery)
        #expect(navigation.path == [.pedalDetail(pedalID)])

        navigation.path.removeLast()
        #expect(navigation.rootNavigation.visibility == .visible)
        #expect(navigation.rootNavigation.selectedDestination == .gallery)

        // Same rule for Jam and Pedalboard detail.
        navigation.selectedDestination = .jam
        let boardID = UUID()
        navigation.openPedalboard(id: boardID)

        #expect(navigation.rootNavigation.visibility == .hidden)
        #expect(navigation.selectedDestination == .jam)
        #expect(navigation.path == [.pedalboardDetail(boardID)])

        navigation.path.removeLast()
        #expect(navigation.rootNavigation.visibility == .visible)
        #expect(navigation.rootNavigation.selectedDestination == .jam)
    }

    @Test func tabStacksRemainIndependentAcrossSelectionChanges() {
        let navigation = AppNavigationModel()
        let pedalID = UUID()
        let boardID = UUID()

        navigation.galleryPath = [.pedalDetail(pedalID)]
        navigation.selectedDestination = .jam
        navigation.jamPath = [.pedalboardDetail(boardID)]

        #expect(navigation.rootNavigation.visibility == .hidden)
        #expect(navigation.path == [.pedalboardDetail(boardID)])

        navigation.selectedDestination = .gallery
        #expect(navigation.rootNavigation.visibility == .hidden)
        #expect(navigation.path == [.pedalDetail(pedalID)])

        navigation.galleryPath.removeAll()
        #expect(navigation.rootNavigation.visibility == .visible)
        #expect(navigation.jamPath == [.pedalboardDetail(boardID)])
    }

    @Test func captureFlowHidesRootNavigationAndCancelRestoresIt() {
        let navigation = AppNavigationModel()
        navigation.selectedDestination = .jam

        navigation.beginCapture()
        #expect(navigation.rootNavigation.visibility == .hidden)
        #expect(navigation.selectedDestination == .jam)

        navigation.cancelCapture()
        #expect(navigation.rootNavigation.visibility == .visible)
        #expect(navigation.rootNavigation.selectedDestination == .jam)

        navigation.beginCapture()
        navigation.completeCapture()
        #expect(navigation.rootNavigation.visibility == .visible)
        #expect(navigation.rootNavigation.selectedDestination == .gallery)
    }

    @Test func pedalDetailRouteHidesBottomBarWithoutChangingSelectedRoot() {
        let navigation = AppNavigationModel()
        let pedalID = UUID()
        navigation.path = [.pedalDetail(pedalID)]

        #expect(navigation.selectedDestination == .gallery)
        #expect(navigation.path == [.pedalDetail(pedalID)])
        #expect(navigation.rootNavigation.visibility == .hidden)

        navigation.path.removeLast()
        #expect(navigation.rootNavigation.visibility == .visible)
        #expect(navigation.rootNavigation.selectedDestination == .gallery)
    }

    @Test func pedalboardDetailRouteHidesBottomBarWithoutChangingSelectedRoot() {
        let navigation = AppNavigationModel()
        let boardID = UUID()
        navigation.selectedDestination = .jam
        navigation.path = [.pedalboardDetail(boardID)]

        #expect(navigation.selectedDestination == .jam)
        #expect(navigation.path == [.pedalboardDetail(boardID)])
        #expect(navigation.rootNavigation.visibility == .hidden)
    }

    @Test func navigationOpensPedalboardDetailByPersistentID() {
        let navigation = AppNavigationModel()
        let boardID = UUID()

        navigation.openPedalboard(id: boardID)

        #expect(navigation.selectedDestination == .jam)
        #expect(navigation.path == [.pedalboardDetail(boardID)])
    }

    @Test func detailRouteUsesOnlyPersistentID() {
        let pedalID = UUID()
        let boardID = UUID()

        #expect(AppRoute.pedalDetail(pedalID) == .pedalDetail(pedalID))
        #expect(AppRoute.pedalboardDetail(boardID) == .pedalboardDetail(boardID))
    }

    @Test func captureKeepsPrecedenceOverRootAndDetailState() {
        let navigation = AppNavigationModel()
        navigation.path = [.pedalDetail(UUID())]
        navigation.beginCapture()

        #expect(navigation.path.count == 1)
        #expect(navigation.isPresentingCapture)
        #expect(navigation.rootNavigation.visibility == .hidden)
    }

    @Test func bottomBarCapturePhasesDeriveExpectedPresentations() {
        guard case .contextual(let picker) = BottomBarPresentation.captureFlow(.picker) else {
            Issue.record("Expected picker contextual presentation")
            return
        }
        #expect(picker.primaryAction?.id == .openCamera)
        #expect(picker.secondaryAction?.id == .cancel)

        #expect(BottomBarPresentation.captureFlow(.processing) == .hidden(.processing))
        #expect(BottomBarPresentation.captureFlow(.camera) == .hidden(.camera))

        guard case .contextual(let retry) = BottomBarPresentation.captureFlow(.saveRetry) else {
            Issue.record("Expected retry contextual presentation")
            return
        }
        #expect(retry.primaryAction?.id == .tryAgain)
        #expect(retry.secondaryAction?.id == .discard)
        #expect(retry.secondaryAction?.role == .destructive)

        guard case .contextual(let result) = BottomBarPresentation.captureFlow(.result) else {
            Issue.record("Expected result contextual presentation")
            return
        }
        #expect(result.primaryAction?.id == .savePedal)
        #expect(result.secondaryAction?.id == .retake)
        #expect(result.primaryAction?.isEnabled == true)

        guard case .contextual(let disabledResult) = BottomBarPresentation.captureFlow(.result, canCompleteResult: false) else {
            Issue.record("Expected disabled result contextual presentation")
            return
        }
        #expect(disabledResult.primaryAction?.id == .savePedal)
        #expect(disabledResult.primaryAction?.isEnabled == false)

        guard case .contextual(let loadingResult) = BottomBarPresentation.captureFlow(.result, isCompletingResult: true) else {
            Issue.record("Expected loading result contextual presentation")
            return
        }
        #expect(loadingResult.primaryAction?.id == .savePedal)
        #expect(loadingResult.primaryAction?.isLoading == true)
    }

    #if DEBUG
    @Test func debugResultFixtureOpensResultWithoutCompletionAvailability() {
        let model = PhotoPedalViewModel(store: PedalStore(directory: temporaryDirectory()))

        model.loadDebugResultForBottomBarValidation(canComplete: false)

        #expect(model.pedal?.name == "Debug Pedal")
        #expect(model.cover != nil)
        #expect(model.canCompleteResult == false)

        model.loadDebugResultForBottomBarValidation()

        #expect(model.pedal?.name == "Debug Pedal")
        #expect(model.cover != nil)
        #expect(model.canCompleteResult == true)
    }
    #endif

    @Test func galleryStateReloadQuickPlayAndDelete() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let player = PlayerDouble()
        let model = GalleryViewModel(store: store, player: player)
        model.reload()
        if case .empty = model.state {} else { Issue.record("Expected empty Gallery") }

        let item = pedal(name: "Playable")
        try store.save(item, cover: cover(.blue))
        model.reload()
        guard let stored = model.state.pedals.first else {
            Issue.record("Expected saved pedal")
            return
        }
        model.quickPlay(stored)
        #expect(player.playedID == item.id)
        model.delete(stored)
        if case .empty = model.state {} else { Issue.record("Expected empty Gallery after delete") }
    }

    @Test func galleryReportsPlaybackFailureWithoutDroppingCollection() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let player = PlayerDouble(shouldFail: true)
        let item = pedal(name: "Fail to play")
        try store.save(item, cover: cover(.blue))
        let model = GalleryViewModel(store: store, player: player)
        model.reload()
        model.quickPlay(try #require(model.state.pedals.first))
        #expect(model.playbackErrorMessage != nil)
        #expect(model.state.pedals.count == 1)
    }

    @Test func galleryAsyncReloadLoadsSavedCollection() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let item = pedal(name: "Async")
        try store.save(item, cover: cover(.blue))
        let model = GalleryViewModel(store: store, player: PlayerDouble())

        await model.reloadAsync()

        #expect(model.state.pedals.map(\.id) == [item.id])
    }

    @Test func galleryThumbnailAssetIsCachedAfterReload() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let item = pedal(name: "Cached Asset")
        try store.save(item, cover: cover(.blue))
        let model = GalleryViewModel(store: store, player: PlayerDouble())

        model.reload()
        let cachedAsset = try #require(model.thumbnailAsset(for: item.id))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("pedals").appendingPathComponent("\(item.id.uuidString).png"))

        #expect(store.thumbnailAsset(for: item.id) == nil)
        #expect(model.thumbnailAsset(for: item.id) == cachedAsset)
    }

    @Test func galleryStopOnlyStopsCurrentPedal() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let player = PlayerDouble()
        let current = pedal(name: "Current")
        let other = pedal(name: "Other")
        try store.save(current, cover: cover(.blue))
        try store.save(other, cover: cover(.orange))
        let model = GalleryViewModel(store: store, player: player)
        model.reload()
        let currentItem = try #require(model.state.pedals.first(where: { $0.id == current.id }))
        let otherItem = try #require(model.state.pedals.first(where: { $0.id == other.id }))

        model.quickPlay(currentItem)
        model.stop(otherItem)
        #expect(player.isPlaying)
        #expect(model.playingID == current.id)

        model.stop(currentItem)
        #expect(!player.isPlaying)
        #expect(model.playingID == nil)
        #expect(player.stopCount == 1)
    }

    private func temporaryDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func png(_ image: UIImage) -> Data { image.pngData()! }
    private func cover(_ color: UIColor) -> UIImage { UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { color.setFill(); $0.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) } }
    private func pedal(id: UUID = UUID(), name: String, date: Date = .now) -> PhotoPedal {
        PhotoPedal(id: id, name: name, description: "Test", sequence: PedalSequence(harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100), notes: [], soundProfile: .legacy), effect: .reverb, createdAt: date, coverFilename: "latest-pedal.png")
    }
}

@MainActor
private final class PlayerDouble: PedalPlaying {
    let shouldFail: Bool
    var stopHandler: ((PhotoPedalSynthStopReason) -> Void)?
    private(set) var playedID: UUID?
    private(set) var isPlaying = false
    private(set) var stopCount = 0

    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }

    func play(_ pedal: PhotoPedal) throws {
        if shouldFail { throw CocoaError(.coderInvalidValue) }
        playedID = pedal.id
        isPlaying = true
    }

    func stop() {
        stopCount += 1
        isPlaying = false
    }
}

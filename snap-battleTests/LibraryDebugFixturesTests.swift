#if DEBUG
import Foundation
import Testing
import UIKit
@testable import snap_battle

struct LibraryDebugFixturesTests {
    @Test(arguments: LibraryDebugDataset.allCases)
    func datasetsHaveExactCountsAndStableIDs(_ dataset: LibraryDebugDataset) {
        let first = (0..<dataset.count).map { LibraryDebugFixtureStore.pedal(index: $0, dataset: dataset) }
        let second = (0..<dataset.count).map { LibraryDebugFixtureStore.pedal(index: $0, dataset: dataset) }

        #expect(first.count == dataset.count)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(Set(first.map(\.id)).count == dataset.count)
    }

    @Test func fixturesCoverMonthsTiesLongTextAndAllDomainOptions() {
        let pedals = (0..<LibraryDebugDataset.large.count).map { LibraryDebugFixtureStore.pedal(index: $0, dataset: .large) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let months = Set(pedals.map { calendar.dateComponents([.year, .month], from: $0.createdAt) })
        let tiedDates = Dictionary(grouping: pedals, by: \.createdAt).values.contains { $0.count > 1 }

        #expect(months.count >= 12)
        #expect(tiedDates)
        #expect(pedals.contains { $0.name.count > 24 })
        #expect(pedals.contains { $0.description.count > 140 })
        #expect(Set(pedals.map(\.effect)) == Set(PedalEffect.allCases))
        #expect(Set(pedals.map { $0.sequence.harmony.scale }) == Set(PedalScale.allCases))
    }

    @Test func syntheticCoversAreReproducibleAndSmall() throws {
        let first = LibraryDebugFixtureStore.cover(index: 42).pngData()
        let second = LibraryDebugFixtureStore.cover(index: 42).pngData()

        #expect(first == second)
        #expect((first?.count ?? .max) < 20_000)
    }

    @Test func fixtureStoreUsesDedicatedDirectoryAndClearPreservesRealDirectory() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let fixtures = LibraryDebugFixtureStore(rootDirectory: base)
        let real = base.appendingPathComponent("real-pedals")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try Data("real".utf8).write(to: real.appendingPathComponent("keep.txt"))

        let store = try fixtures.install(.small)
        #expect(store.loadCollection().pedals.count == 50)
        fixtures.reset(dataset: .small)
        #expect(FileManager.default.fileExists(atPath: real.appendingPathComponent("keep.txt").path))
        #expect(!FileManager.default.fileExists(atPath: store.debugCollectionDirectory.path))
    }

    @Test(arguments: LibraryDebugDataset.allCases)
    func validFixturesHaveNoIssuesWithoutCorruptSentinel(_ dataset: LibraryDebugDataset) throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let fixtures = LibraryDebugFixtureStore(rootDirectory: base)
        let store = try fixtures.install(dataset)
        let sentinel = store.debugCollectionDirectory.appendingPathComponent("D06B0000-0000-4000-8000-FFFFFFFFFFFF.json")
        try FileManager.default.removeItem(at: sentinel)

        let result = store.loadCollection()

        #expect(result.pedals.count == dataset.count)
        #expect(result.issues.isEmpty)
    }

    @Test(arguments: LibraryDebugDataset.allCases)
    func corruptSentinelIsolatedFromAllValidFixtures(_ dataset: LibraryDebugDataset) throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = try LibraryDebugFixtureStore(rootDirectory: base).install(dataset)

        let result = store.loadCollection()

        #expect(result.pedals.count == dataset.count)
        #expect(result.issues.count == 1)
        #expect(result.hasPartialError)
    }
}
#endif

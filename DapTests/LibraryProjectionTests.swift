import Foundation
import Testing
import UIKit
@testable import Dap

struct LibraryProjectionTests {
    @Test func emptyCollectionProducesNoSections() {
        #expect(LibraryProjection.sections(from: []).isEmpty)
    }

    @Test func singleItemProducesOneSectionAndPreservesItemID() {
        let item = storedPedal(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, date: date(2026, 7, 17))

        let sections = LibraryProjection.sections(from: [item])

        #expect(sections.map(\.id) == [YearMonth(year: 2026, month: 7)])
        #expect(sections.first?.items.map(\.id) == [item.id])
    }

    @Test func itemsAreDescendingByDateWithinAndAcrossMonths() {
        let items = [
            storedPedal(id: id(3), date: date(2026, 7, 17)),
            storedPedal(id: id(1), date: date(2025, 12, 31)),
            storedPedal(id: id(2), date: date(2026, 1, 1)),
            storedPedal(id: id(4), date: date(2026, 7, 1))
        ]

        let sections = LibraryProjection.sections(from: items)

        #expect(sections.map(\.id) == [YearMonth(year: 2026, month: 7), YearMonth(year: 2026, month: 1), YearMonth(year: 2025, month: 12)])
        #expect(sections.flatMap { $0.items }.map(\.id) == [id(3), id(4), id(2), id(1)])
    }

    @Test func equalDatesUseUUIDAsDeterministicTieBreak() {
        let date = date(2026, 7, 17)
        let first = storedPedal(id: id(1), date: date)
        let second = storedPedal(id: id(2), date: date)

        let sections = LibraryProjection.sections(from: [second, first])

        #expect(sections.flatMap { $0.items }.map(\.id) == [first.id, second.id])
    }

    @Test func sectionIDsDoNotDependOnLocalizedTitles() {
        let item = storedPedal(id: id(1), date: date(2026, 7, 17))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let sections = LibraryProjection.sections(from: [item], calendar: calendar)

        #expect(sections.first?.id == YearMonth(year: 2026, month: 7))
    }

    @Test func projectionDoesNotMutateInputOrderOrContents() {
        let older = storedPedal(id: id(1), date: date(2025, 1, 1))
        let newer = storedPedal(id: id(2), date: date(2026, 1, 1))
        let input = [newer, older]

        _ = LibraryProjection.sections(from: input)

        #expect(input.map(\.id) == [newer.id, older.id])
        #expect(input.map { $0.pedal.name } == [newer.pedal.name, older.pedal.name])
    }

    @Test func latestSelectionRemainsNewestAndDoesNotUseLibraryProjection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let older = storedPedal(id: id(1), date: date(2025, 1, 1))
        let newer = storedPedal(id: id(2), date: date(2026, 1, 1))
        try store.save(older.pedal, cover: older.cover)
        try store.save(newer.pedal, cover: newer.cover)

        let sections = LibraryProjection.sections(from: [newer, older])

        #expect(sections.flatMap { $0.items }.map(\.id) == [newer.id, older.id])
        #expect(store.loadLatest()?.id == newer.id)
    }

    private func storedPedal(id: UUID, date: Date) -> StoredPedal {
        StoredPedal(pedal: PhotoPedal(id: id, name: id.uuidString, description: "Test", sequence: PedalSequence(harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100), notes: [], soundProfile: .legacy), effect: .reverb, createdAt: date, coverFilename: "latest-pedal.png"), cover: cover())
    }

    private func id(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func cover() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

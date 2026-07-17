import Foundation

nonisolated struct YearMonth: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month], from: date)
        year = components.year ?? 0
        month = components.month ?? 0
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }
}

nonisolated struct LibrarySection: Identifiable, Equatable {
    let id: YearMonth
    let items: [StoredPedal]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.items.map(\.id) == rhs.items.map(\.id) && lhs.items.map(\.pedal) == rhs.items.map(\.pedal)
    }
}

enum LibraryProjection {
    nonisolated static func sections(
        from pedals: [StoredPedal],
        calendar: Calendar = .current
    ) -> [LibrarySection] {
        let ordered = pedals.sorted(by: ascendingOrder)
        let grouped = Dictionary(grouping: ordered) {
            YearMonth(date: $0.pedal.createdAt, calendar: calendar)
        }

        return grouped.keys.sorted().compactMap { month in
            guard let items = grouped[month] else { return nil }
            return LibrarySection(id: month, items: items)
        }
    }

    private nonisolated static func ascendingOrder(_ lhs: StoredPedal, _ rhs: StoredPedal) -> Bool {
        if lhs.pedal.createdAt != rhs.pedal.createdAt {
            return lhs.pedal.createdAt < rhs.pedal.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

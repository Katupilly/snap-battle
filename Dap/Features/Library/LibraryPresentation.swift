import Foundation
import UIKit

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
        let ordered = PedalStore.ordered(pedals)
        let grouped = Dictionary(grouping: ordered) {
            YearMonth(date: $0.pedal.createdAt, calendar: calendar)
        }

        return grouped.keys.sorted(by: >).compactMap { month in
            guard let items = grouped[month] else { return nil }
            return LibrarySection(id: month, items: items.sorted(by: descendingOrder))
        }
    }

    private nonisolated static func descendingOrder(_ lhs: StoredPedal, _ rhs: StoredPedal) -> Bool {
        if lhs.pedal.createdAt != rhs.pedal.createdAt {
            return lhs.pedal.createdAt > rhs.pedal.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

@MainActor
final class GalleryEntryHaptics {
    private var task: Task<Void, Never>?

    func play(reduceMotion: Bool) {
        guard !reduceMotion else { return }
        task?.cancel()
        let generators = Dictionary(uniqueKeysWithValues: GalleryImpactStyle.allCases.map {
            ($0, UIImpactFeedbackGenerator(style: $0.uiStyle))
        })
        generators.values.forEach { $0.prepare() }
        task = Task { @MainActor in
            var previousDelay = 0.0
            for event in Self.events {
                do {
                    let interval = event.delay - previousDelay
                    if interval > 0 {
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                } catch { return }
                guard !Task.isCancelled else { return }
                generators[event.impactStyle]?.impactOccurred(intensity: event.intensity)
                generators[event.impactStyle]?.prepare()
                previousDelay = event.delay
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private static let events = [
        GalleryHapticEvent(delay: 0, intensity: 0.42, impactStyle: .light),
        GalleryHapticEvent(delay: 0.055, intensity: 0.50, impactStyle: .light),
        GalleryHapticEvent(delay: 0.110, intensity: 0.58, impactStyle: .light),
        GalleryHapticEvent(delay: 0.170, intensity: 0.66, impactStyle: .light),
        GalleryHapticEvent(delay: 0.240, intensity: 0.68, impactStyle: .medium)
    ]
}

private struct GalleryHapticEvent {
    let delay: Double
    let intensity: CGFloat
    let impactStyle: GalleryImpactStyle
}

private enum GalleryImpactStyle: CaseIterable {
    case light
    case medium

    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: .light
        case .medium: .medium
        }
    }
}

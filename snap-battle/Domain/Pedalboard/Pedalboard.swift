import Foundation

nonisolated struct Pedalboard: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var entries: [PedalboardEntry]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date,
        updatedAt: Date? = nil,
        entries: [PedalboardEntry] = []
    ) {
        self.id = id
        self.name = Pedalboard.normalize(name)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.entries = entries
    }

    static let defaultName = "Pedalboard"

    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultName : trimmed
    }
}

nonisolated struct PedalboardEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let pedalID: StoredPedal.ID

    init(id: UUID = UUID(), pedalID: StoredPedal.ID) {
        self.id = id
        self.pedalID = pedalID
    }
}

nonisolated struct PedalboardDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let pedalboard: Pedalboard

    init(schemaVersion: Int = PedalboardDocument.currentSchemaVersion, pedalboard: Pedalboard) {
        self.schemaVersion = schemaVersion
        self.pedalboard = pedalboard
    }
}

enum PedalboardMutation {
    static func make(
        name: String,
        now: Date,
        id: UUID = UUID(),
        createdAt: Date? = nil
    ) -> Pedalboard {
        Pedalboard(id: id, name: Pedalboard.normalize(name), createdAt: createdAt ?? now, updatedAt: now, entries: [])
    }

    static func addPedal(_ pedalID: StoredPedal.ID, to board: Pedalboard, now: Date) -> Pedalboard {
        var updated = board
        updated.entries.append(PedalboardEntry(pedalID: pedalID))
        updated.updatedAt = now
        return updated
    }

    @discardableResult
    static func removeEntry(id entryID: PedalboardEntry.ID, from board: Pedalboard, now: Date) -> Pedalboard {
        var updated = board
        let originalCount = updated.entries.count
        updated.entries.removeAll { $0.id == entryID }
        guard updated.entries.count != originalCount else { return board }
        updated.updatedAt = now
        return updated
    }

    static func moveEntry(id entryID: PedalboardEntry.ID, to destination: Int, in board: Pedalboard, now: Date) -> Pedalboard? {
        guard let sourceIndex = board.entries.firstIndex(where: { $0.id == entryID }) else { return nil }
        let count = board.entries.count
        let clamped = max(0, min(destination, count - 1))
        guard clamped != sourceIndex else { return board }
        var updated = board
        let entry = updated.entries.remove(at: sourceIndex)
        updated.entries.insert(entry, at: clamped)
        updated.updatedAt = now
        return updated
    }

    @discardableResult
    static func rename(_ raw: String, board: Pedalboard, now: Date) -> Pedalboard {
        let normalized = Pedalboard.normalize(raw)
        guard normalized != board.name else { return board }
        var updated = board
        updated.name = normalized
        updated.updatedAt = now
        return updated
    }
}

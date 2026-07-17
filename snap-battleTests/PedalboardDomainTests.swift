import Foundation
import Testing
@testable import snap_battle

struct PedalboardDomainTests {
    @Test func normalizationFallsBackToNeutralDefaultWhenNameIsEmptyOrWhitespace() {
        #expect(Pedalboard.normalize("") == Pedalboard.defaultName)
        #expect(Pedalboard.normalize("   ") == Pedalboard.defaultName)
        #expect(Pedalboard.normalize("\n\t  \n") == Pedalboard.defaultName)
    }

    @Test func normalizationTrimsEdgesAndPreservesInnerCharacters() {
        #expect(Pedalboard.normalize("  My Board  ") == "My Board")
        #expect(Pedalboard.normalize("\nMy Board\n") == "My Board")
        #expect(Pedalboard.normalize("A B C") == "A B C")
    }

    @Test func makeSetsCreatedAndUpdatedToSameInstantWhenNotProvided() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let board = PedalboardMutation.make(name: "Hello", now: now)

        #expect(board.name == "Hello")
        #expect(board.createdAt == now)
        #expect(board.updatedAt == now)
        #expect(board.entries.isEmpty)
        #expect(board.id != UUID())
    }

    @Test func makeNormalizesEmptyNameWithoutReferencingLocale() {
        let now = Date(timeIntervalSince1970: 1)
        let board = PedalboardMutation.make(name: "  ", now: now)

        #expect(board.name == Pedalboard.defaultName)
        #expect(board.name == "Pedalboard")
    }

    @Test func addPedalAppendsAndRefreshesUpdatedAt() {
        let now = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        let board = PedalboardMutation.make(name: "B", now: now)
        let pedalA = UUID()
        let updated = PedalboardMutation.addPedal(pedalA, to: board, now: later)

        #expect(updated.entries.count == 1)
        #expect(updated.entries[0].pedalID == pedalA)
        #expect(updated.entries[0].id != UUID())
        #expect(updated.updatedAt == later)
        #expect(updated.createdAt == now)
    }

    @Test func duplicatePedalsProduceDistinctEntryIDs() {
        let now = Date(timeIntervalSince1970: 100)
        var board = PedalboardMutation.make(name: "B", now: now)
        let pedal = UUID()
        board = PedalboardMutation.addPedal(pedal, to: board, now: now)
        board = PedalboardMutation.addPedal(pedal, to: board, now: now)

        #expect(board.entries.count == 2)
        #expect(board.entries.allSatisfy { $0.pedalID == pedal })
        let entryIDs = Set(board.entries.map(\.id))
        #expect(entryIDs.count == 2)
    }

    @Test func removeEntryDropsOnlyTargetEntryAndPreservesOthers() {
        let now = Date(timeIntervalSince1970: 100)
        var board = PedalboardMutation.make(name: "B", now: now)
        let p1 = UUID(), p2 = UUID(), p3 = UUID()
        board = PedalboardMutation.addPedal(p1, to: board, now: now)
        board = PedalboardMutation.addPedal(p2, to: board, now: now)
        board = PedalboardMutation.addPedal(p3, to: board, now: now)
        let middleID = board.entries[1].id

        let removed = PedalboardMutation.removeEntry(id: middleID, from: board, now: Date(timeIntervalSince1970: 200))

        #expect(removed.entries.count == 2)
        #expect(removed.entries.map(\.pedalID) == [p1, p3])
        #expect(removed.updatedAt == Date(timeIntervalSince1970: 200))
    }

    @Test func removeEntryIsNoOpForUnknownIDAndDoesNotRefreshUpdatedAt() {
        let now = Date(timeIntervalSince1970: 100)
        let board = PedalboardMutation.make(name: "B", now: now)
        let result = PedalboardMutation.removeEntry(id: UUID(), from: board, now: Date(timeIntervalSince1970: 200))

        #expect(result == board)
        #expect(result.updatedAt == board.updatedAt)
    }

    @Test func moveEntryReordersAndPreservesIDs() {
        let now = Date(timeIntervalSince1970: 100)
        var board = PedalboardMutation.make(name: "B", now: now)
        let p1 = UUID(), p2 = UUID(), p3 = UUID()
        board = PedalboardMutation.addPedal(p1, to: board, now: now)
        board = PedalboardMutation.addPedal(p2, to: board, now: now)
        board = PedalboardMutation.addPedal(p3, to: board, now: now)
        let firstID = board.entries[0].id

        let moved = PedalboardMutation.moveEntry(id: firstID, to: 2, in: board, now: Date(timeIntervalSince1970: 300))

        #expect(moved?.entries.map(\.pedalID) == [p2, p3, p1])
        #expect(moved?.entries.first(where: { $0.pedalID == p1 })?.id == firstID)
        #expect(moved?.updatedAt == Date(timeIntervalSince1970: 300))
    }

    @Test func moveEntryClampsDestinationOutOfBoundsAndReturnsBoardForSameIndex() {
        let now = Date(timeIntervalSince1970: 100)
        var board = PedalboardMutation.make(name: "B", now: now)
        board = PedalboardMutation.addPedal(UUID(), to: board, now: now)
        board = PedalboardMutation.addPedal(UUID(), to: board, now: now)
        let firstID = board.entries[0].id

        let overflow = PedalboardMutation.moveEntry(id: firstID, to: 99, in: board, now: now)
        let negative = PedalboardMutation.moveEntry(id: firstID, to: -5, in: board, now: now)
        let same = PedalboardMutation.moveEntry(id: firstID, to: 0, in: board, now: now)

        #expect(overflow?.entries.map(\.pedalID) == [board.entries[1].pedalID, board.entries[0].pedalID])
        #expect(negative == board)
        #expect(same == board)
    }

    @Test func moveEntryReturnsNilForUnknownID() {
        let now = Date(timeIntervalSince1970: 100)
        let board = PedalboardMutation.make(name: "B", now: now)

        let result = PedalboardMutation.moveEntry(id: UUID(), to: 0, in: board, now: now)

        #expect(result == nil)
    }

    @Test func renamePreservesCreatedAtAndRefreshesUpdatedAt() {
        let created = Date(timeIntervalSince1970: 100)
        let board = Pedalboard(id: UUID(), name: "Original", createdAt: created, updatedAt: created, entries: [])

        let renamed = PedalboardMutation.rename("  New Name  ", board: board, now: Date(timeIntervalSince1970: 500))

        #expect(renamed.name == "New Name")
        #expect(renamed.createdAt == created)
        #expect(renamed.updatedAt == Date(timeIntervalSince1970: 500))
    }

    @Test func renameFallsBackToDefaultWhenNormalizedEmpty() {
        let now = Date(timeIntervalSince1970: 100)
        let board = PedalboardMutation.make(name: "Old", now: now)

        let renamed = PedalboardMutation.rename("   ", board: board, now: Date(timeIntervalSince1970: 200))

        #expect(renamed.name == Pedalboard.defaultName)
        #expect(renamed.updatedAt == Date(timeIntervalSince1970: 200))
    }

    @Test func renameIsNoOpWhenResultMatchesCurrentName() {
        let now = Date(timeIntervalSince1970: 100)
        let board = PedalboardMutation.make(name: "Same", now: now)

        let renamed = PedalboardMutation.rename("  Same  ", board: board, now: Date(timeIntervalSince1970: 200))

        #expect(renamed == board)
        #expect(renamed.updatedAt == board.updatedAt)
    }

    @Test func codableRoundTripPreservesAllFields() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let board = Pedalboard(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "Round Trip",
            createdAt: now,
            updatedAt: now,
            entries: [
                PedalboardEntry(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, pedalID: UUID(uuidString: "FFFFFFFF-1111-2222-3333-444444444444")!),
                PedalboardEntry(id: UUID(uuidString: "11112222-3333-4444-5555-666677778888")!, pedalID: UUID(uuidString: "99998888-7777-6666-5555-444433332222")!)
            ]
        )

        let data = try JSONEncoder().encode(PedalboardDocument(pedalboard: board))
        let decoded = try JSONDecoder().decode(PedalboardDocument.self, from: data)

        #expect(decoded.schemaVersion == PedalboardDocument.currentSchemaVersion)
        #expect(decoded.pedalboard == board)
    }

    @Test func documentEnvelopeEncodesSchemaVersionOne() throws {
        let now = Date(timeIntervalSince1970: 0)
        let board = PedalboardMutation.make(name: "V1", now: now)
        let data = try JSONEncoder().encode(PedalboardDocument(pedalboard: board))

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["schemaVersion"] as? Int == 1)
    }

    @Test func orderingHelperAppliesUpdatedAtThenCreatedAtThenIDAscending() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 200)

        let aID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let bID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let newerByUpdate = Pedalboard(id: aID, name: "A", createdAt: t0, updatedAt: t2, entries: [])
        let newerByCreate = Pedalboard(id: bID, name: "B", createdAt: t1, updatedAt: t1, entries: [])

        let ordered = PedalboardStore.ordered([newerByCreate, newerByUpdate])
        #expect(ordered.map(\.id) == [aID, bID])
    }

    @Test func orderingHelperBreaksTiesByIDAscending() {
        let now = Date(timeIntervalSince1970: 100)
        let lowID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!

        let high = Pedalboard(id: highID, name: "H", createdAt: now, updatedAt: now, entries: [])
        let low = Pedalboard(id: lowID, name: "L", createdAt: now, updatedAt: now, entries: [])

        let ordered = PedalboardStore.ordered([high, low])
        #expect(ordered.map(\.id) == [lowID, highID])
    }

    @Test func invalidMutationsDoNotCorruptBoard() {
        let now = Date(timeIntervalSince1970: 100)
        let board = PedalboardMutation.make(name: "B", now: now)
        let original = board

        _ = PedalboardMutation.removeEntry(id: UUID(), from: board, now: Date(timeIntervalSince1970: 200))
        _ = PedalboardMutation.moveEntry(id: UUID(), to: 99, in: board, now: Date(timeIntervalSince1970: 200))
        _ = PedalboardMutation.moveEntry(id: board.entries.first?.id ?? UUID(), to: 0, in: board, now: Date(timeIntervalSince1970: 200))

        #expect(board == original)
    }
}

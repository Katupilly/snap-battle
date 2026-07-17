import Foundation
import Testing
@testable import snap_battle

struct PedalboardStoreTests {
    @Test func saveAndLoadRoundTripPreservesBoard() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let board = makeBoard(name: "Round Trip", entries: 3)

        try store.save(board)
        let loaded = try store.load(id: board.id)

        #expect(loaded == board)
    }

    @Test func loadCollectionReturnsMultipleBoardsInStableOrder() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let a = makeBoard(name: "A", createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 500))
        let b = makeBoard(name: "B", createdAt: Date(timeIntervalSince1970: 200), updatedAt: Date(timeIntervalSince1970: 400))
        let c = makeBoard(name: "C", createdAt: Date(timeIntervalSince1970: 300), updatedAt: Date(timeIntervalSince1970: 600))
        try store.save(a)
        try store.save(b)
        try store.save(c)

        let result = store.loadCollection()

        #expect(result.boards.map(\.id) == [c.id, a.id, b.id])
        #expect(result.issues.isEmpty)
    }

    @Test func updatingOneBoardDoesNotAffectOtherBoards() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let original = makeBoard(name: "Original", entries: 1)
        let other = makeBoard(name: "Other", entries: 2)
        try store.save(original)
        try store.save(other)

        let renamed = PedalboardMutation.rename("Renamed", board: original, now: Date(timeIntervalSince1970: 999))
        try store.save(renamed)

        let reloadedOther = try store.load(id: other.id)
        #expect(reloadedOther.name == "Other")
        #expect(reloadedOther.entries.count == 2)
    }

    @Test func deleteRemovesOnlyTargetBoard() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let target = makeBoard(name: "Target")
        let keep = makeBoard(name: "Keep")
        try store.save(target)
        try store.save(keep)

        try store.delete(id: target.id)

        #expect(throws: PedalboardStoreError.missingRecord) { try store.load(id: target.id) }
        let result = store.loadCollection()
        #expect(result.boards.map(\.id) == [keep.id])
        #expect(result.issues.isEmpty)
    }

    @Test func orderingUsesUpdatedAtDescendingWithTieBreakers() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let sameTime = Date(timeIntervalSince1970: 1_000)
        let olderTime = Date(timeIntervalSince1970: 900)
        let newerCreate = makeBoard(name: "NewerCreate", id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-000000000001")!, createdAt: sameTime, updatedAt: sameTime)
        let olderCreateSameUpdate = makeBoard(name: "OlderCreate", id: UUID(uuidString: "11111111-1111-1111-1111-000000000001")!, createdAt: olderTime, updatedAt: sameTime)
        let newestUpdate = makeBoard(name: "NewestUpdate", id: UUID(uuidString: "22222222-2222-2222-2222-000000000001")!, createdAt: sameTime, updatedAt: Date(timeIntervalSince1970: 2_000))
        try store.save(newerCreate)
        try store.save(olderCreateSameUpdate)
        try store.save(newestUpdate)

        let ordered = store.loadCollection().boards.map(\.name)

        #expect(ordered == ["NewestUpdate", "NewerCreate", "OlderCreate"])
    }

    @Test func corruptedJSONProducesIssueAndPreservesValidBoards() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let valid = makeBoard(name: "Valid")
        try store.save(valid)
        try Data("not a json".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("\(UUID().uuidString).json"))

        let result = store.loadCollection()

        #expect(result.boards.map(\.id) == [valid.id])
        #expect(result.issues.count == 1)
        #expect(result.hasPartialError)
    }

    @Test func unknownSchemaVersionProducesIssueAndPreservesTheFile() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let valid = makeBoard(name: "Valid")
        try store.save(valid)

        let futureID = UUID()
        let futureDocument = PedalboardDocument(schemaVersion: 999, pedalboard: makeBoard(name: "Future", id: futureID))
        try JSONEncoder().encode(futureDocument).write(to: store.debugCollectionDirectory.appendingPathComponent("\(futureID.uuidString).json"))

        let result = store.loadCollection()

        #expect(result.boards.map(\.id) == [valid.id])
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains("999"))
        let preservedURL = store.debugCollectionDirectory.appendingPathComponent("\(futureID.uuidString).json")
        let preservedData = try Data(contentsOf: preservedURL)
        let preservedDoc = try JSONDecoder().decode(PedalboardDocument.self, from: preservedData)

        #expect(preservedDoc == futureDocument)
    }

    @Test func missingPedalReferenceSurvivesRoundTrip() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let ghostID = UUID()
        let board = makeBoard(name: "HasGhost", entries: [ghostID, UUID(), ghostID])
        try store.save(board)

        let reloaded = try store.load(id: board.id)

        #expect(reloaded.entries.map(\.pedalID) == [ghostID, reloaded.entries[1].pedalID, ghostID])
        let uniqueEntries = Set(reloaded.entries.map(\.id))
        #expect(uniqueEntries.count == 3)
    }

    @Test func duplicateEntriesArePreservedAcrossSaveAndLoad() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let pedalID = UUID()
        let board = makeBoard(name: "Dupes", entries: [pedalID, pedalID, pedalID])
        try store.save(board)

        let reloaded = try store.load(id: board.id)
        #expect(reloaded.entries.count == 3)
        #expect(reloaded.entries.allSatisfy { $0.pedalID == pedalID })
        #expect(Set(reloaded.entries.map(\.id)).count == 3)
    }

    @Test func loadCollectionIgnoresPedalStoreDirectory() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let pedalDirectory = directory.appendingPathComponent("pedals", isDirectory: true)
        try FileManager.default.createDirectory(at: pedalDirectory, withIntermediateDirectories: true)
        try Data("definitely not a pedalboard".utf8).write(to: pedalDirectory.appendingPathComponent("\(UUID().uuidString).json"))

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(FileManager.default.fileExists(atPath: pedalDirectory.appendingPathComponent("\(UUID(uuidString: "99999999-9999-9999-9999-999999999999")!).json").path) || true)
    }

    @Test func emptyDirectoryReturnsEmptyCollection() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(FileManager.default.fileExists(atPath: store.debugCollectionDirectory.path))
    }

    @Test func missingDirectoryIsCreatedOnFirstCall() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let nested = directory.appendingPathComponent("nested/root", isDirectory: true)
        let store = PedalboardStore(directory: nested)

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(FileManager.default.fileExists(atPath: store.debugCollectionDirectory.path))
    }

    @Test func repeatedSaveReplacesSameFileWithoutAccumulating() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let original = makeBoard(name: "Original")
        try store.save(original)
        let firstSaveCount = countJSONFiles(in: store)

        let updated = PedalboardMutation.rename("Updated", board: original, now: Date(timeIntervalSince1970: 1_000))
        try store.save(updated)
        let secondSaveCount = countJSONFiles(in: store)

        #expect(firstSaveCount == 1)
        #expect(secondSaveCount == 1)
        #expect(try store.load(id: original.id).name == "Updated")
    }

    @Test func writeFailureBeforePromotionDoesNotCreateFinalFile() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let failingWriter: (Data, URL) throws -> Void = { _, _ in throw NSError(domain: "pedalboard.test", code: 1) }
        let store = PedalboardStore(directory: directory, writeData: failingWriter)
        let board = makeBoard(name: "Will Not Save")

        #expect(throws: (any Error).self) { try store.save(board) }
        #expect(!FileManager.default.fileExists(atPath: store.debugCollectionDirectory.appendingPathComponent("\(board.id.uuidString).json").path))
    }

    @Test func writeFailureDuringPromotionDoesNotCorruptExistingFile() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = makeBoard(name: "Original")
        let firstStore = PedalboardStore(directory: directory)
        try firstStore.save(original)

        let failingWriter: (Data, URL) throws -> Void = { _, url in
            if url.lastPathComponent.contains(".tmp-") {
                throw NSError(domain: "pedalboard.test", code: 1)
            }
            try Data(contentsOf: url).write(to: url, options: .atomic)
        }
        let store = PedalboardStore(directory: directory, writeData: failingWriter)
        let renamed = PedalboardMutation.rename("Renamed", board: original, now: Date(timeIntervalSince1970: 9_999))

        #expect(throws: (any Error).self) { try store.save(renamed) }
        let stillThere = try store.load(id: original.id)
        #expect(stillThere.name == "Original")
    }

    @Test func partialTempFilesAreCleanedOnNextLoad() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("\(UUID().uuidString).tmp-abcd.json"))

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.debugCollectionDirectory.path).isEmpty)
    }

    @Test func deletionMarkerIsRemovedOnResave() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let board = makeBoard(name: "Marked")
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        try Data("deleted".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("\(board.id.uuidString).deleted"))

        #expect(throws: PedalboardStoreError.missingRecord) { try store.save(board) }

        _ = store.loadCollection()
        try store.save(PedalboardMutation.rename("After Clean", board: board, now: Date(timeIntervalSince1970: 1)))
        let reloaded = try store.load(id: board.id)
        #expect(reloaded.name == "After Clean")
        #expect(!FileManager.default.fileExists(atPath: store.debugCollectionDirectory.appendingPathComponent("\(board.id.uuidString).deleted").path))
    }

    @Test func unknownFileExtensionsAreIgnoredAndDoNotProduceIssues() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        try Data("noise".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("README.txt"))
        try Data("noise".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("orphan.png"))

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.isEmpty)
    }

    @Test func filenameCannotEscapeCollectionDirectory() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        try store.save(makeBoard(name: "A"))
        try store.save(makeBoard(name: "B"))

        let names = try FileManager.default.contentsOfDirectory(atPath: store.debugCollectionDirectory.path).sorted()
        #expect(names.allSatisfy { $0.hasSuffix(".json") })
        #expect(names.allSatisfy { !$0.contains("/") && !$0.contains("..") })
    }

    @Test func loadCollectionRejectsBogusUUIDFilenames() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("not-a-uuid.json"))
        try Data("{}".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("123.json"))
        try Data("{}".utf8).write(to: store.debugCollectionDirectory.appendingPathComponent("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.json"))

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.isEmpty)
    }

    @Test func sharedStoreWritesIntoDefaultApplicationSupportSubdirectory() {
        let expected = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pedalboards", isDirectory: true)
        #expect(PedalboardStore.shared.debugCollectionDirectory.standardizedFileURL.path == expected.standardizedFileURL.path)
    }

    @Test func loadCollectionCanBeObservedByInjection() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var calls = 0
        let store = PedalboardStore(directory: directory, loadCollectionDidRun: { calls += 1 })

        _ = store.loadCollection()
        _ = store.loadCollection()

        #expect(calls == 2)
    }

    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func countJSONFiles(in store: PedalboardStore) -> Int {
        let urls = (try? FileManager.default.contentsOfDirectory(at: store.debugCollectionDirectory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }.count
    }

    private func makeBoard(
        name: String,
        id: UUID = UUID(),
        entries count: Int = 0,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Pedalboard {
        let entries = (0..<count).map { _ in PedalboardEntry(pedalID: UUID()) }
        return Pedalboard(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt, entries: entries)
    }

    private func makeBoard(
        name: String,
        id: UUID = UUID(),
        entries pedalIDs: [UUID],
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Pedalboard {
        let entries = pedalIDs.map { PedalboardEntry(pedalID: $0) }
        return Pedalboard(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt, entries: entries)
    }
}

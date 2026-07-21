import Foundation
import Testing
@testable import Dap

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

    @Test func truncatedJSONProducesIssueAndPreservesValidBoards() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let valid = makeBoard(name: "Valid")
        try store.save(valid)

        let truncatedID = UUID()
        let truncatedURL = store.debugCollectionDirectory.appendingPathComponent("\(truncatedID.uuidString).json")
        try Data(#"{"schemaVersion":1,"pedalboard":{"id":"\#(truncatedID.uuidString)","name":"T"#.utf8).write(to: truncatedURL)

        let result = store.loadCollection()

        #expect(result.boards.map(\.id) == [valid.id])
        #expect(result.issues.count == 1)
        #expect(result.hasPartialError)
        #expect(FileManager.default.fileExists(atPath: truncatedURL.path))
        let preserved = try Data(contentsOf: truncatedURL)
        #expect(preserved == Data(#"{"schemaVersion":1,"pedalboard":{"id":"\#(truncatedID.uuidString)","name":"T"#.utf8))
    }

    @Test func pedalboardIdMismatchWithFilenameProducesIssueAndPreservesFile() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let valid = makeBoard(name: "Valid")
        try store.save(valid)

        let filenameID = UUID()
        let declaredID = UUID()
        let divergent = Pedalboard(id: declaredID, name: "Divergent", createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 1), entries: [])
        let document = PedalboardDocument(pedalboard: divergent)
        let url = store.debugCollectionDirectory.appendingPathComponent("\(filenameID.uuidString).json")
        try JSONEncoder().encode(document).write(to: url)

        let result = store.loadCollection()

        #expect(result.boards.map(\.id) == [valid.id])
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains(filenameID.uuidString))
        let reloaded = try Data(contentsOf: url)
        let reloadedDoc = try JSONDecoder().decode(PedalboardDocument.self, from: reloaded)
        #expect(reloadedDoc == document)
        #expect(throws: PedalboardStoreError.self) { try store.load(id: filenameID) }
    }

    @Test func orphanBackupIsCleanedByLoadCollectionWithoutAffectingValidBoards() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let valid = makeBoard(name: "Valid")
        try store.save(valid)

        let orphanID = UUID()
        let orphanURL = store.debugCollectionDirectory.appendingPathComponent("\(orphanID.uuidString).tmp-backup-orphan.json")
        try Data(#"{"schemaVersion":1,"pedalboard":{"id":"\#(orphanID.uuidString)","name":"Orphan","entries":[]}}"#.utf8).write(to: orphanURL)

        let result = store.loadCollection()

        #expect(result.boards.map(\.id) == [valid.id])
        #expect(result.issues.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
    }

    @Test func validPromotionBackupIsRestoredWhenFinalFileIsMissing() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let board = makeBoard(name: "Recover Me")
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        let backupURL = promotionBackupURL(for: board.id, token: "a", in: store)
        let expectedData = try writeDocument(for: board, to: backupURL)

        let result = store.loadCollection()

        let finalURL = finalURL(for: board.id, in: store)
        #expect(result.boards == [board])
        #expect(result.issues.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
        #expect(try Data(contentsOf: finalURL) == expectedData)
    }

    @Test func validFinalFileWinsOverPromotionBackup() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let finalBoard = makeBoard(name: "Newest", updatedAt: Date(timeIntervalSince1970: 2_000))
        let backupBoard = makeBoard(name: "Older", id: finalBoard.id, updatedAt: Date(timeIntervalSince1970: 1_000))
        try store.save(finalBoard)
        let finalURL = finalURL(for: finalBoard.id, in: store)
        let finalData = try Data(contentsOf: finalURL)
        let backupURL = promotionBackupURL(for: finalBoard.id, token: "b", in: store)
        try writeDocument(for: backupBoard, to: backupURL)

        let result = store.loadCollection()

        #expect(result.boards == [finalBoard])
        #expect(result.issues.isEmpty)
        #expect(try Data(contentsOf: finalURL) == finalData)
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
    }

    @Test func invalidPromotionBackupWithoutFinalProducesIssueAndIsPreserved() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let boardID = UUID()
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        let backupURL = promotionBackupURL(for: boardID, token: "bad", in: store)
        let invalidData = Data("not a pedalboard document".utf8)
        try invalidData.write(to: backupURL)

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains(boardID.uuidString))
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        #expect(try Data(contentsOf: backupURL) == invalidData)
    }

    @Test func validPromotionBackupRestoresOverInvalidFinalFile() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let board = makeBoard(name: "Recovered")
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        let finalURL = finalURL(for: board.id, in: store)
        let invalidFinal = Data("truncated".utf8)
        try invalidFinal.write(to: finalURL)
        let backupURL = promotionBackupURL(for: board.id, token: "c", in: store)
        let expectedData = try writeDocument(for: board, to: backupURL)

        let result = store.loadCollection()

        #expect(result.boards == [board])
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains("substituído por backup válido"))
        #expect(try Data(contentsOf: finalURL) == expectedData)
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
        let preservedInvalid = try FileManager.default.contentsOfDirectory(atPath: store.debugCollectionDirectory.path)
            .filter { $0.hasPrefix("\(board.id.uuidString).json.invalid-") }
        #expect(preservedInvalid.count == 1)
        #expect(try Data(contentsOf: store.debugCollectionDirectory.appendingPathComponent(preservedInvalid[0])) == invalidFinal)
    }

    @Test func repeatedPromotionBackupRecoveryIsIdempotent() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let board = makeBoard(name: "Once")
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        let backupURL = promotionBackupURL(for: board.id, token: "d", in: store)
        let expectedData = try writeDocument(for: board, to: backupURL)

        let first = store.loadCollection()
        let second = store.loadCollection()

        let finalURL = finalURL(for: board.id, in: store)
        #expect(first.boards == [board])
        #expect(second.boards == [board])
        #expect(first.issues.isEmpty)
        #expect(second.issues.isEmpty)
        #expect(try Data(contentsOf: finalURL) == expectedData)
    }

    @Test func promotionBackupForOneBoardDoesNotAffectAnotherBoard() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let recovered = makeBoard(name: "Recovered", updatedAt: Date(timeIntervalSince1970: 2_000))
        let untouched = makeBoard(name: "Untouched", updatedAt: Date(timeIntervalSince1970: 1_000))
        try store.save(untouched)
        let untouchedData = try Data(contentsOf: finalURL(for: untouched.id, in: store))
        let backupURL = promotionBackupURL(for: recovered.id, token: "e", in: store)
        try writeDocument(for: recovered, to: backupURL)

        let result = store.loadCollection()

        #expect(result.boards.map(\.id) == [recovered.id, untouched.id])
        #expect(result.issues.isEmpty)
        #expect(try Data(contentsOf: finalURL(for: untouched.id, in: store)) == untouchedData)
    }

    @Test func multiplePromotionBackupsUseDeterministicUpdatedCreatedAndFilenameOrder() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)

        let boardID = UUID()
        let lowerUpdated = makeBoard(
            name: "Lower Updated",
            id: boardID,
            createdAt: Date(timeIntervalSince1970: 500),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newerUpdatedOlderCreated = makeBoard(
            name: "Newer Updated Older Created",
            id: boardID,
            createdAt: Date(timeIntervalSince1970: 400),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let tiedDatesLaterFilename = makeBoard(
            name: "Tied Dates Later Filename",
            id: boardID,
            createdAt: Date(timeIntervalSince1970: 900),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let selected = makeBoard(
            name: "Selected",
            id: boardID,
            createdAt: Date(timeIntervalSince1970: 900),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let untouched = makeBoard(
            name: "Untouched",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let lowerUpdatedURL = promotionBackupURL(for: boardID, token: "d-lower-updated", in: store)
        let olderCreatedURL = promotionBackupURL(for: boardID, token: "c-older-created", in: store)
        let laterFilenameURL = promotionBackupURL(for: boardID, token: "z-later-filename", in: store)
        let selectedURL = promotionBackupURL(for: boardID, token: "a-selected-filename", in: store)
        try writeDocument(for: lowerUpdated, to: lowerUpdatedURL)
        try writeDocument(for: newerUpdatedOlderCreated, to: olderCreatedURL)
        try writeDocument(for: tiedDatesLaterFilename, to: laterFilenameURL)
        let selectedData = try writeDocument(for: selected, to: selectedURL)
        try store.save(untouched)
        let untouchedData = try Data(contentsOf: finalURL(for: untouched.id, in: store))

        let first = store.loadCollection()
        let second = store.loadCollection()

        let restoredFinal = finalURL(for: boardID, in: store)
        #expect(first.boards.map(\.id) == [boardID, untouched.id])
        #expect(second.boards.map(\.id) == [boardID, untouched.id])
        #expect(first.boards.first == selected)
        #expect(second.boards.first == selected)
        #expect(first.issues.isEmpty)
        #expect(second.issues.isEmpty)
        #expect(try Data(contentsOf: restoredFinal) == selectedData)
        #expect(try Data(contentsOf: finalURL(for: untouched.id, in: store)) == untouchedData)
        #expect(!FileManager.default.fileExists(atPath: lowerUpdatedURL.path))
        #expect(!FileManager.default.fileExists(atPath: olderCreatedURL.path))
        #expect(!FileManager.default.fileExists(atPath: laterFilenameURL.path))
        #expect(!FileManager.default.fileExists(atPath: selectedURL.path))
    }

    @Test func commonTemporaryFilesAreCleanedWithoutDeletingRecoverableBackup() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let board = makeBoard(name: "Recoverable")
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        let commonTemp = store.debugCollectionDirectory.appendingPathComponent("\(UUID().uuidString).tmp-common.json")
        try Data("partial".utf8).write(to: commonTemp)
        let backupURL = promotionBackupURL(for: board.id, token: "f", in: store)
        let expectedData = try writeDocument(for: board, to: backupURL)

        let result = store.loadCollection()

        #expect(result.boards == [board])
        #expect(result.issues.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: commonTemp.path))
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
        #expect(try Data(contentsOf: finalURL(for: board.id, in: store)) == expectedData)
    }

    @Test func duplicateEntryIDWithDifferentPedalsIsRejectedAndPreserved() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let duplicateID = UUID()
        let board = makeBoard(
            name: "Duplicate Different Pedals",
            entries: [
                PedalboardEntry(id: duplicateID, pedalID: UUID()),
                PedalboardEntry(id: duplicateID, pedalID: UUID())
            ]
        )
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        let url = finalURL(for: board.id, in: store)
        let originalData = try writeDocument(for: board, to: url)

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains("duplicate entry id"))
        #expect(result.issues[0].contains(duplicateID.uuidString))
        #expect(try Data(contentsOf: url) == originalData)
    }

    @Test func duplicateEntryIDWithSamePedalIsRejected() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let duplicateID = UUID()
        let pedalID = UUID()
        let board = makeBoard(
            name: "Duplicate Same Pedal",
            entries: [
                PedalboardEntry(id: duplicateID, pedalID: pedalID),
                PedalboardEntry(id: duplicateID, pedalID: pedalID)
            ]
        )
        try FileManager.default.createDirectory(at: store.debugCollectionDirectory, withIntermediateDirectories: true)
        try writeDocument(for: board, to: finalURL(for: board.id, in: store))

        let result = store.loadCollection()

        #expect(result.boards.isEmpty)
        #expect(result.issues.count == 1)
        #expect(result.issues[0].contains("duplicate entry id"))
    }

    @Test func repeatedPedalIDWithDistinctEntryIDsRemainsValid() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let pedalID = UUID()
        let board = makeBoard(
            name: "Same Pedal",
            entries: [
                PedalboardEntry(id: UUID(), pedalID: pedalID),
                PedalboardEntry(id: UUID(), pedalID: pedalID)
            ]
        )
        try store.save(board)

        let result = store.loadCollection()

        #expect(result.boards == [board])
        #expect(result.issues.isEmpty)
    }

    @Test func invalidDuplicateEntryBoardIsIsolatedFromValidBoard() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalboardStore(directory: directory)
        let valid = makeBoard(name: "Valid")
        try store.save(valid)
        let duplicateID = UUID()
        let invalid = makeBoard(
            name: "Invalid",
            entries: [
                PedalboardEntry(id: duplicateID, pedalID: UUID()),
                PedalboardEntry(id: duplicateID, pedalID: UUID())
            ]
        )
        let invalidURL = finalURL(for: invalid.id, in: store)
        let invalidData = try writeDocument(for: invalid, to: invalidURL)

        let result = store.loadCollection()

        #expect(result.boards == [valid])
        #expect(result.issues.count == 1)
        #expect(result.hasPartialError)
        #expect(try Data(contentsOf: invalidURL) == invalidData)
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

    private func makeBoard(
        name: String,
        id: UUID = UUID(),
        entries: [PedalboardEntry],
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Pedalboard {
        Pedalboard(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt, entries: entries)
    }

    @discardableResult
    private func writeDocument(for board: Pedalboard, to url: URL) throws -> Data {
        let data = try JSONEncoder().encode(PedalboardDocument(pedalboard: board))
        try data.write(to: url)
        return data
    }

    private func finalURL(for id: UUID, in store: PedalboardStore) -> URL {
        store.debugCollectionDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func promotionBackupURL(for id: UUID, token: String, in store: PedalboardStore) -> URL {
        store.debugCollectionDirectory.appendingPathComponent("\(id.uuidString).json.tmp-backup-\(token)")
    }
}

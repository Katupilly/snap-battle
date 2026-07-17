import Foundation

struct PedalboardStoreLoadResult: Equatable, Sendable {
    let boards: [Pedalboard]
    let issues: [String]

    var hasPartialError: Bool { !boards.isEmpty && !issues.isEmpty }
    var hasBlockingError: Bool { boards.isEmpty && !issues.isEmpty }
}

enum PedalboardStoreError: LocalizedError, Sendable, Equatable {
    case missingRecord
    case validationFailed(String)
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .missingRecord:
            return "Este pedalboard não está mais disponível."
        case .validationFailed(let detail):
            return "O pedalboard salvo não pôde ser validado: \(detail)"
        case .unsupportedSchemaVersion(let version):
            return "Esta versão de pedalboard (\(version)) ainda não é compatível."
        }
    }
}

nonisolated struct PedalboardStore {
    static let shared = PedalboardStore()

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let writeData: (Data, URL) throws -> Void
    private let loadCollectionDidRun: (() -> Void)?

    init(
        directory: URL? = nil,
        fileManager: FileManager = .default,
        writeData: @escaping (Data, URL) throws -> Void = { data, url in try data.write(to: url, options: .atomic) },
        loadCollectionDidRun: (() -> Void)? = nil
    ) {
        rootDirectory = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileManager = fileManager
        self.writeData = writeData
        self.loadCollectionDidRun = loadCollectionDidRun
    }

    private var collectionDirectory: URL { rootDirectory.appendingPathComponent("pedalboards", isDirectory: true) }

    #if DEBUG
    var debugCollectionDirectory: URL { collectionDirectory }
    #endif

    static func ordered(_ boards: [Pedalboard]) -> [Pedalboard] {
        boards.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func loadCollection() -> PedalboardStoreLoadResult {
        loadCollectionDidRun?()
        var issues: [String] = []
        do {
            try ensureCollectionDirectory()
            cleanupTemporaryArtifacts()
            cleanupDeletionMarkers()
        } catch {
            issues.append(error.localizedDescription)
        }

        guard fileManager.fileExists(atPath: collectionDirectory.path) else {
            return PedalboardStoreLoadResult(boards: [], issues: issues)
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(at: collectionDirectory, includingPropertiesForKeys: nil)
        } catch {
            issues.append(error.localizedDescription)
            return PedalboardStoreLoadResult(boards: [], issues: issues)
        }

        var boards: [Pedalboard] = []
        let candidates = urls.filter { url in
            url.pathExtension == "json"
                && !url.lastPathComponent.contains(".tmp-")
                && !url.lastPathComponent.hasSuffix(".deleted")
        }
        for url in candidates {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            do {
                boards.append(try load(id: id))
            } catch let PedalboardStoreError.unsupportedSchemaVersion(version) {
                issues.append("Pedalboard com schema \(version) ignorado: \(url.lastPathComponent)")
            } catch let PedalboardStoreError.validationFailed(detail) {
                issues.append("Pedalboard \(url.lastPathComponent) inválido: \(detail)")
            } catch {
                issues.append("Um pedalboard salvo não pôde ser carregado: \(error.localizedDescription)")
            }
        }
        return PedalboardStoreLoadResult(boards: Self.ordered(boards), issues: issues)
    }

    func load(id: UUID) throws -> Pedalboard {
        let url = jsonURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PedalboardStoreError.missingRecord
        }
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(PedalboardDocument.self, from: data)
        guard document.pedalboard.id == id else {
            throw PedalboardStoreError.validationFailed("id mismatch")
        }
        guard document.schemaVersion == PedalboardDocument.currentSchemaVersion else {
            throw PedalboardStoreError.unsupportedSchemaVersion(document.schemaVersion)
        }
        return document.pedalboard
    }

    func save(_ board: Pedalboard) throws {
        try ensureCollectionDirectory()
        try guardNotDeletionMarked(board.id)
        let document = PedalboardDocument(pedalboard: board)
        let json = try JSONEncoder().encode(document)
        let token = UUID().uuidString
        let temporary = temporaryURL(for: board.id, token: token)
        defer { try? fileManager.removeItem(at: temporary) }
        try writeData(json, temporary)
        try validateTemporaryJSON(id: board.id, url: temporary)
        try promote(temporary, to: jsonURL(for: board.id), token: token)
        _ = try load(id: board.id)
        try? fileManager.removeItem(at: deletionMarkerURL(for: board.id))
    }

    func delete(id: UUID) throws {
        let final = jsonURL(for: id)
        guard fileManager.fileExists(atPath: final.path) else {
            throw PedalboardStoreError.missingRecord
        }
        let token = UUID().uuidString
        let backup = temporaryURL(for: id, token: "delete-\(token)")
        let marker = deletionMarkerURL(for: id)
        let hadMarker = fileManager.fileExists(atPath: marker.path)
        do {
            try fileManager.moveItem(at: final, to: backup)
            do {
                try writeData(Data("deleted".utf8), marker)
                try? fileManager.removeItem(at: backup)
            } catch {
                if fileManager.fileExists(atPath: backup.path) {
                    try? fileManager.moveItem(at: backup, to: final)
                }
                if !hadMarker { try? fileManager.removeItem(at: marker) }
                throw error
            }
        } catch {
            if fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: final)
            }
            if !hadMarker { try? fileManager.removeItem(at: marker) }
            throw error
        }
    }

    private func ensureCollectionDirectory() throws {
        try fileManager.createDirectory(at: collectionDirectory, withIntermediateDirectories: true)
    }

    private func cleanupTemporaryArtifacts() {
        guard let urls = try? fileManager.contentsOfDirectory(at: collectionDirectory, includingPropertiesForKeys: nil) else { return }
        for url in urls where url.lastPathComponent.contains(".tmp-") {
            try? fileManager.removeItem(at: url)
        }
    }

    private func cleanupDeletionMarkers() {
        guard let urls = try? fileManager.contentsOfDirectory(at: collectionDirectory, includingPropertiesForKeys: nil) else { return }
        for url in urls where url.lastPathComponent.hasSuffix(".deleted") {
            try? fileManager.removeItem(at: url)
        }
    }

    private func guardNotDeletionMarked(_ id: UUID) throws {
        if fileManager.fileExists(atPath: deletionMarkerURL(for: id).path) {
            throw PedalboardStoreError.missingRecord
        }
    }

    private func jsonURL(for id: UUID) -> URL {
        collectionDirectory.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private func deletionMarkerURL(for id: UUID) -> URL {
        collectionDirectory.appendingPathComponent("\(id.uuidString).deleted", isDirectory: false)
    }

    private func temporaryURL(for id: UUID, token: String) -> URL {
        collectionDirectory.appendingPathComponent("\(id.uuidString).tmp-\(token).json", isDirectory: false)
    }

    private func validateTemporaryJSON(id: UUID, url: URL) throws {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(PedalboardDocument.self, from: data)
        guard document.pedalboard.id == id else {
            throw PedalboardStoreError.validationFailed("temporary file id mismatch")
        }
        guard document.schemaVersion == PedalboardDocument.currentSchemaVersion else {
            throw PedalboardStoreError.unsupportedSchemaVersion(document.schemaVersion)
        }
    }

    private func promote(_ temporary: URL, to final: URL, token: String) throws {
        let backup = final.deletingLastPathComponent().appendingPathComponent("\(final.lastPathComponent).tmp-backup-\(token)")
        if fileManager.fileExists(atPath: final.path) {
            try fileManager.moveItem(at: final, to: backup)
        }
        do {
            try fileManager.moveItem(at: temporary, to: final)
            try? fileManager.removeItem(at: backup)
        } catch {
            if fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: final)
            }
            throw error
        }
    }
}

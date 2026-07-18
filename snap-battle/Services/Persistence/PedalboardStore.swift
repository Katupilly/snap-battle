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
            recoverInterruptedPromotions(issues: &issues)
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
        return try loadValidatedPedalboard(id: id, url: url)
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
        for url in urls where commonTemporaryFileID(for: url) != nil {
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
        _ = try loadValidatedPedalboard(id: id, url: url)
    }

    private func loadValidatedPedalboard(id: UUID, url: URL) throws -> Pedalboard {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(PedalboardDocument.self, from: data)
        do {
            return try document.validatedPedalboard(expectedID: id)
        } catch PedalboardDocumentValidationError.unsupportedSchemaVersion(let version) {
            throw PedalboardStoreError.unsupportedSchemaVersion(version)
        } catch let error as PedalboardDocumentValidationError {
            throw PedalboardStoreError.validationFailed(error.detail)
        }
    }

    private func recoverInterruptedPromotions(issues: inout [String]) {
        guard let urls = try? fileManager.contentsOfDirectory(at: collectionDirectory, includingPropertiesForKeys: nil) else { return }
        let backupsByID = Dictionary(grouping: urls.compactMap(promotionBackup(for:)), by: \.id)
        for id in backupsByID.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let backups = backupsByID[id] else { continue }
            let final = jsonURL(for: id)
            let finalState = validateExistingFinal(id: id, final: final)
            if finalState.isValid {
                backups.forEach { try? fileManager.removeItem(at: $0.url) }
                continue
            }

            let validBackups = backups.compactMap { backup -> ValidPromotionBackup? in
                do {
                    let board = try loadValidatedPedalboard(id: id, url: backup.url)
                    return ValidPromotionBackup(url: backup.url, board: board)
                } catch {
                    return nil
                }
            }

            guard let selected = selectBackupToRestore(from: validBackups) else {
                if !finalState.exists {
                    issues.append("Backup de pedalboard \(id.uuidString) inválido; restauração ignorada.")
                }
                continue
            }

            do {
                if finalState.exists {
                    let invalid = final.deletingLastPathComponent()
                        .appendingPathComponent("\(final.lastPathComponent).invalid-\(UUID().uuidString)")
                    try? fileManager.removeItem(at: invalid)
                    try fileManager.moveItem(at: final, to: invalid)
                    issues.append("Pedalboard \(final.lastPathComponent) inválido substituído por backup válido.")
                }
                try fileManager.moveItem(at: selected.url, to: final)
                backups
                    .filter { $0.url != selected.url }
                    .forEach { try? fileManager.removeItem(at: $0.url) }
            } catch {
                issues.append("Backup de pedalboard \(id.uuidString) não pôde ser restaurado: \(error.localizedDescription)")
            }
        }
    }

    private func validateExistingFinal(id: UUID, final: URL) -> (exists: Bool, isValid: Bool) {
        guard fileManager.fileExists(atPath: final.path) else { return (false, false) }
        do {
            _ = try loadValidatedPedalboard(id: id, url: final)
            return (true, true)
        } catch {
            return (true, false)
        }
    }

    private func selectBackupToRestore(from backups: [ValidPromotionBackup]) -> ValidPromotionBackup? {
        backups.sorted { lhs, rhs in
            if lhs.board.updatedAt != rhs.board.updatedAt { return lhs.board.updatedAt > rhs.board.updatedAt }
            if lhs.board.createdAt != rhs.board.createdAt { return lhs.board.createdAt > rhs.board.createdAt }
            return lhs.url.lastPathComponent < rhs.url.lastPathComponent
        }.first
    }

    private func promotionBackup(for url: URL) -> PromotionBackup? {
        let marker = ".json.tmp-backup-"
        let name = url.lastPathComponent
        guard let range = name.range(of: marker) else { return nil }
        let idText = String(name[..<range.lowerBound])
        guard let id = UUID(uuidString: idText) else { return nil }
        return PromotionBackup(id: id, url: url)
    }

    private func commonTemporaryFileID(for url: URL) -> UUID? {
        let name = url.lastPathComponent
        guard name.hasSuffix(".json"), let range = name.range(of: ".tmp-") else { return nil }
        let idText = String(name[..<range.lowerBound])
        return UUID(uuidString: idText)
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

private struct PromotionBackup {
    let id: UUID
    let url: URL
}

private struct ValidPromotionBackup {
    let url: URL
    let board: Pedalboard
}

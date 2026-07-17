import Foundation
import UIKit

nonisolated struct StoredPedal: Identifiable {
    let pedal: PhotoPedal
    let cover: UIImage
    nonisolated var id: UUID { pedal.id }
}

struct PedalStoreLoadResult {
    let pedals: [StoredPedal]
    let issues: [String]

    var hasPartialError: Bool { !pedals.isEmpty && !issues.isEmpty }
    var hasBlockingError: Bool { pedals.isEmpty && !issues.isEmpty }
}

enum PedalStoreError: LocalizedError {
    case imageEncoding
    case validationFailed
    case missingRecord

    var errorDescription: String? {
        switch self {
        case .imageEncoding: "Não foi possível preparar a capa para salvar."
        case .validationFailed: "O pedal salvo não pôde ser validado."
        case .missingRecord: "Este pedal não está mais disponível."
        }
    }
}

nonisolated struct PedalStore {
    static let shared = PedalStore()

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

    private var collectionDirectory: URL { rootDirectory.appendingPathComponent("pedals", isDirectory: true) }

    #if DEBUG
    var debugCollectionDirectory: URL { collectionDirectory }
    #endif
    private var legacyJSONURL: URL { rootDirectory.appendingPathComponent("latest-pedal.json") }
    private var legacyPNGURL: URL { rootDirectory.appendingPathComponent("latest-pedal.png") }

    static func ordered(_ pedals: [StoredPedal]) -> [StoredPedal] {
        pedals.sorted {
            if $0.pedal.createdAt != $1.pedal.createdAt { return $0.pedal.createdAt > $1.pedal.createdAt }
            return $0.pedal.id.uuidString < $1.pedal.id.uuidString
        }
    }

    func loadCollection(diagnosticsRunID: String? = nil) -> PedalStoreLoadResult {
        loadCollectionDidRun?()
        let runID = diagnosticsRunID ?? PerformanceDiagnostics.makeRunID()
        let started = ContinuousClock.now
        var issues: [String] = []
        do {
            try ensureCollectionDirectory()
            cleanupTemporaryArtifacts()
            try migrateLegacyIfNeeded()
        } catch {
            issues.append(error.localizedDescription)
        }

        guard fileManager.fileExists(atPath: collectionDirectory.path) else {
            let result = PedalStoreLoadResult(pedals: [], issues: issues)
            PerformanceDiagnostics.event("galleryReload", runID: runID, details: "pedals=0 issues=\(issues.count) durationMs=\(Self.milliseconds(started.duration(to: .now)))")
            return result
        }

        do {
            let urls = try fileManager.contentsOfDirectory(at: collectionDirectory, includingPropertiesForKeys: nil)
            let identifiers = Set(urls.compactMap { url -> UUID? in
                guard ["json", "png"].contains(url.pathExtension), !url.lastPathComponent.contains(".tmp-") else { return nil }
                return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            })
            var stored: [StoredPedal] = []
            for id in identifiers {
                do { stored.append(try load(id: id)) }
                catch { issues.append("Um pedal salvo não pôde ser carregado: \(error.localizedDescription)") }
            }
            let result = PedalStoreLoadResult(pedals: Self.ordered(stored), issues: issues)
            PerformanceDiagnostics.event("galleryReload", runID: runID, details: "pedals=\(result.pedals.count) issues=\(issues.count) durationMs=\(Self.milliseconds(started.duration(to: .now)))")
            return result
        } catch {
            issues.append(error.localizedDescription)
            let result = PedalStoreLoadResult(pedals: [], issues: issues)
            PerformanceDiagnostics.event("galleryReload", runID: runID, details: "pedals=0 issues=\(issues.count) durationMs=\(Self.milliseconds(started.duration(to: .now)))")
            return result
        }
    }

    func load(id: UUID) throws -> StoredPedal {
        let pedal = try JSONDecoder().decode(PhotoPedal.self, from: Data(contentsOf: jsonURL(for: id)))
        guard pedal.id == id, let cover = UIImage(contentsOfFile: pngURL(for: id).path) else { throw PedalStoreError.validationFailed }
        return StoredPedal(pedal: pedal, cover: cover)
    }

    /// Returns the persisted cover identity used by the Library thumbnail loader.
    /// The store remains the owner of the collection path; callers never build
    /// file URLs from a grid index or from display data.
    func thumbnailAsset(for id: UUID) -> PersistedImageAsset? {
        let url = pngURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return PersistedImageAsset(identity: id.uuidString, fileURL: url)
    }

    func thumbnailAssets(for pedals: [StoredPedal]) -> [UUID: PersistedImageAsset] {
        Dictionary(uniqueKeysWithValues: pedals.map { pedal in
            (pedal.id, PersistedImageAsset(identity: pedal.id.uuidString, fileURL: pngURL(for: pedal.id)))
        })
    }

    func save(_ pedal: PhotoPedal, cover: UIImage, diagnosticsRunID: String? = nil) throws {
        let runID = diagnosticsRunID ?? PerformanceDiagnostics.makeRunID()
        let started = ContinuousClock.now
        try ensureCollectionDirectory()
        let png = try pngData(from: cover)
        let json = try JSONEncoder().encode(pedal)
        let token = UUID().uuidString
        let temporaryJSON = temporaryURL(for: pedal.id, ext: "json", token: token)
        let temporaryPNG = temporaryURL(for: pedal.id, ext: "png", token: token)
        defer { try? fileManager.removeItem(at: temporaryJSON); try? fileManager.removeItem(at: temporaryPNG) }

        try writeData(json, temporaryJSON)
        try writeData(png, temporaryPNG)
        try validateTemporaryPair(id: pedal.id, jsonURL: temporaryJSON, pngURL: temporaryPNG)
        try promote(temporaryJSON, to: jsonURL(for: pedal.id), token: token)
        try promote(temporaryPNG, to: pngURL(for: pedal.id), token: token)
        _ = try load(id: pedal.id)
        try? fileManager.removeItem(at: deletionMarkerURL(for: pedal.id))
        PerformanceDiagnostics.event("persistenceCompleted", runID: runID, details: "jsonBytes=\(json.count) pngBytes=\(png.count) durationMs=\(Self.milliseconds(started.duration(to: .now)))")
    }

    func updateMetadata(id: UUID, name: String, description: String, diagnosticsRunID: String? = nil) throws -> StoredPedal {
        let runID = diagnosticsRunID ?? PerformanceDiagnostics.makeRunID()
        let started = ContinuousClock.now
        try ensureCollectionDirectory()
        guard !isDeletionMarked(id) else { throw PedalStoreError.missingRecord }
        let current = try load(id: id)
        let draft = try PedalDraftValidator().validate(PedalDraft(name: name, description: description))
        let updated = current.pedal.updatingMetadata(name: draft.name, description: draft.description)
        let json = try JSONEncoder().encode(updated)
        let token = UUID().uuidString
        let temporaryJSON = temporaryURL(for: id, ext: "json", token: "metadata-\(token)")
        defer { try? fileManager.removeItem(at: temporaryJSON) }

        try writeData(json, temporaryJSON)
        try validateMetadataUpdateTemporaryJSON(id: id, original: current.pedal, jsonURL: temporaryJSON)
        try promote(temporaryJSON, to: jsonURL(for: id), token: token)
        let stored = try load(id: id)
        PerformanceDiagnostics.event("semanticMetadataUpdate", runID: runID, details: "pedalID=\(id.uuidString) jsonBytes=\(json.count) durationMs=\(Self.milliseconds(started.duration(to: .now)))")
        return stored
    }

    func delete(id: UUID) throws {
        let json = jsonURL(for: id), png = pngURL(for: id)
        guard fileManager.fileExists(atPath: json.path) || fileManager.fileExists(atPath: png.path) else { throw PedalStoreError.missingRecord }
        let token = UUID().uuidString
        let jsonBackup = temporaryURL(for: id, ext: "json", token: "delete-\(token)")
        let pngBackup = temporaryURL(for: id, ext: "png", token: "delete-\(token)")
        let deletionMarker = deletionMarkerURL(for: id)
        let hadDeletionMarker = fileManager.fileExists(atPath: deletionMarker.path)
        do {
            if fileManager.fileExists(atPath: json.path) { try fileManager.moveItem(at: json, to: jsonBackup) }
            if fileManager.fileExists(atPath: png.path) { try fileManager.moveItem(at: png, to: pngBackup) }
            let jsonData = fileManager.fileExists(atPath: jsonBackup.path) ? try Data(contentsOf: jsonBackup) : nil
            let pngData = fileManager.fileExists(atPath: pngBackup.path) ? try Data(contentsOf: pngBackup) : nil
            do {
                try writeData(Data("deleted".utf8), deletionMarker)
                if fileManager.fileExists(atPath: jsonBackup.path) { try fileManager.removeItem(at: jsonBackup) }
                if fileManager.fileExists(atPath: pngBackup.path) { try fileManager.removeItem(at: pngBackup) }
            } catch {
                if let jsonData { try? jsonData.write(to: json, options: .atomic) }
                if let pngData { try? pngData.write(to: png, options: .atomic) }
                if !hadDeletionMarker { try? fileManager.removeItem(at: deletionMarker) }
                throw error
            }
        } catch {
            if fileManager.fileExists(atPath: jsonBackup.path) { try? fileManager.moveItem(at: jsonBackup, to: json) }
            if fileManager.fileExists(atPath: pngBackup.path) { try? fileManager.moveItem(at: pngBackup, to: png) }
            if !hadDeletionMarker { try? fileManager.removeItem(at: deletionMarker) }
            throw error
        }
    }

    func loadLatest() -> StoredPedal? {
        let collection = loadCollection()
        if let first = collection.pedals.first { return first }
        return loadLegacy()
    }

    private func migrateLegacyIfNeeded() throws {
        guard let legacy = loadLegacy() else { return }
        guard !isDeletionMarked(legacy.pedal.id) else { return }
        if (try? load(id: legacy.pedal.id)) != nil { return }
        try save(legacy.pedal, cover: legacy.cover)
    }

    private func loadLegacy() -> StoredPedal? {
        guard let pedal = try? JSONDecoder().decode(PhotoPedal.self, from: Data(contentsOf: legacyJSONURL)),
              let cover = UIImage(contentsOfFile: legacyPNGURL.path) else { return nil }
        guard !isDeletionMarked(pedal.id) else { return nil }
        return StoredPedal(pedal: pedal, cover: cover)
    }

    private func ensureCollectionDirectory() throws {
        try fileManager.createDirectory(at: collectionDirectory, withIntermediateDirectories: true)
    }

    private func cleanupTemporaryArtifacts() {
        guard let urls = try? fileManager.contentsOfDirectory(at: collectionDirectory, includingPropertiesForKeys: nil) else { return }
        for url in urls where url.lastPathComponent.contains(".tmp-") { try? fileManager.removeItem(at: url) }
    }

    private func jsonURL(for id: UUID) -> URL { collectionDirectory.appendingPathComponent("\(id.uuidString).json") }
    private func pngURL(for id: UUID) -> URL { collectionDirectory.appendingPathComponent("\(id.uuidString).png") }
    private func deletionMarkerURL(for id: UUID) -> URL { collectionDirectory.appendingPathComponent("\(id.uuidString).deleted") }
    private func isDeletionMarked(_ id: UUID) -> Bool { fileManager.fileExists(atPath: deletionMarkerURL(for: id).path) }
    private func temporaryURL(for id: UUID, ext: String, token: String) -> URL { collectionDirectory.appendingPathComponent("\(id.uuidString).tmp-\(token).\(ext)") }

    private func pngData(from cover: UIImage) throws -> Data {
        guard let data = cover.pngData() else { throw PedalStoreError.imageEncoding }
        return data
    }

    private static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        let value = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
        return String(format: "%.1f", value)
    }

    private func validateTemporaryPair(id: UUID, jsonURL: URL, pngURL: URL) throws {
        let decoded = try JSONDecoder().decode(PhotoPedal.self, from: Data(contentsOf: jsonURL))
        guard decoded.id == id, UIImage(contentsOfFile: pngURL.path) != nil else { throw PedalStoreError.validationFailed }
    }

    private func validateMetadataUpdateTemporaryJSON(id: UUID, original: PhotoPedal, jsonURL: URL) throws {
        let decoded = try JSONDecoder().decode(PhotoPedal.self, from: Data(contentsOf: jsonURL))
        guard decoded.id == id,
              decoded.createdAt == original.createdAt,
              decoded.sequence == original.sequence,
              decoded.effect == original.effect,
              decoded.coverFilename == original.coverFilename else {
            throw PedalStoreError.validationFailed
        }
        _ = try PedalDraftValidator().validate(PedalDraft(name: decoded.name, description: decoded.description))
    }

    private func promote(_ temporary: URL, to final: URL, token: String) throws {
        let backup = final.deletingLastPathComponent().appendingPathComponent("\(final.lastPathComponent).tmp-backup-\(token)")
        if fileManager.fileExists(atPath: final.path) { try fileManager.moveItem(at: final, to: backup) }
        do {
            try fileManager.moveItem(at: temporary, to: final)
            try? fileManager.removeItem(at: backup)
        } catch {
            if fileManager.fileExists(atPath: backup.path) { try? fileManager.moveItem(at: backup, to: final) }
            throw error
        }
    }
}

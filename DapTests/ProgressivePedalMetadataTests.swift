import Foundation
import Testing
import UIKit
@testable import Dap

@MainActor
struct ProgressivePedalMetadataTests {
    @Test func essentialResultPersistsFallbackBeforeSemanticMetadataCompletes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let generator = ControlledMetadataGenerator()
        let store = PedalStore(directory: directory)
        let model = DapViewModel(store: store, pipeline: pipeline(generator: generator))

        model.process(cover(.blue), runID: "PROG")
        try await waitUntil { model.pedal != nil }

        let saved = try #require(store.loadLatest())
        #expect(model.pedal?.id == saved.pedal.id)
        #expect(model.pedal?.name == "Dap")
        #expect(model.pedal?.description == "A photo-generated sound pedal.")
        #expect(model.cover?.cgImage != nil)
        #expect(model.semanticEnrichmentState == .loading)

        await generator.succeed(PedalDraft(name: "Blue Hour", description: "A calm blue sound."))
        try await waitUntil { model.semanticEnrichmentState == .succeeded }

        #expect(model.pedal?.name == "Blue Hour")
        #expect(store.loadCollection().pedals.count == 1)
    }

    @Test func successfulEnrichmentUpdatesOnlyMetadataForSameRecord() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let original = pedal(name: "Dap", description: "A photo-generated sound pedal.")
        try store.save(original, cover: cover(.orange))

        let updated = try store.updateMetadata(id: original.id, name: "Warm Edge", description: "A bright clipped rhythm.")

        #expect(updated.pedal.id == original.id)
        #expect(updated.pedal.createdAt == original.createdAt)
        #expect(updated.pedal.sequence == original.sequence)
        #expect(updated.pedal.effect == original.effect)
        #expect(updated.pedal.coverFilename == original.coverFilename)
        #expect(updated.pedal.name == "Warm Edge")
        #expect(updated.pedal.description == "A bright clipped rhythm.")
        #expect(store.loadCollection().pedals.count == 1)
        #expect(updated.cover.cgImage != nil)
    }

    @Test func invalidOrFailedEnrichmentKeepsPersistedFallback() async throws {
        let failures: [Result<PedalDraft, AppError>] = [
            .failure(.modelUnavailable("unavailable")),
            .failure(.foundationModelRefused("refused")),
            .failure(.foundationModelFailed("failed")),
            .success(PedalDraft(name: "", description: "")),
            .success(PedalDraft(name: String(repeating: "x", count: 25), description: "Too long name."))
        ]

        for failure in failures {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let generator = ImmediateMetadataGenerator(result: failure)
            let store = PedalStore(directory: directory)
            let model = DapViewModel(store: store, pipeline: pipeline(generator: generator))

            model.process(cover(.blue), runID: "FAIL")
            try await waitUntil { model.pedal != nil && !model.isProcessing }
            try await waitUntil { model.semanticEnrichmentState == .failed }

            let saved = try #require(store.loadLatest())
            #expect(saved.pedal.name == "Dap")
            #expect(saved.pedal.description == "A photo-generated sound pedal.")
            #expect(store.loadCollection().pedals.count == 1)
        }
    }

    @Test func missingCorruptAndDeletedRecordsAreNotRecreatedByMetadataUpdate() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let item = pedal(name: "Dap", description: "A photo-generated sound pedal.")

        #expect(throws: Error.self) {
            try store.updateMetadata(id: item.id, name: "Missing", description: "No record.")
        }

        try store.save(item, cover: cover(.blue))
        let json = directory.appendingPathComponent("pedals").appendingPathComponent("\(item.id.uuidString).json")
        try Data("corrupt".utf8).write(to: json)
        #expect(throws: Error.self) {
            try store.updateMetadata(id: item.id, name: "Corrupt", description: "No update.")
        }

        try? FileManager.default.removeItem(at: directory)
        let deleteDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: deleteDirectory) }
        let deleteStore = PedalStore(directory: deleteDirectory)
        try deleteStore.save(item, cover: cover(.orange))
        try deleteStore.delete(id: item.id)
        #expect(throws: Error.self) {
            try deleteStore.updateMetadata(id: item.id, name: "Deleted", description: "No recreate.")
        }
        #expect(deleteStore.loadCollection().pedals.isEmpty)
    }

    @Test func lateEnrichmentDoesNotRecreateDeletedPedal() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let generator = ControlledMetadataGenerator()
        let store = PedalStore(directory: directory)
        let model = DapViewModel(store: store, pipeline: pipeline(generator: generator))

        model.process(cover(.blue), runID: "DEL")
        try await waitUntil { model.pedal != nil }
        let id = try #require(model.pedal?.id)
        try store.delete(id: id)

        await generator.succeed(PedalDraft(name: "Too Late", description: "This should not return."))
        try await waitUntil { model.semanticEnrichmentState == .failed }

        #expect(store.loadCollection().pedals.isEmpty)
        #expect((try? store.load(id: id)) == nil)
    }

    @Test func galleryUpdatesExistingItemWithoutChangingOrderOrCount() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)
        let older = pedal(name: "Older", description: "Old.", date: Date(timeIntervalSince1970: 1))
        let newer = pedal(name: "Dap", description: "A photo-generated sound pedal.", date: Date(timeIntervalSince1970: 2))
        try store.save(older, cover: cover(.blue))
        try store.save(newer, cover: cover(.orange))
        let model = GalleryViewModel(store: store, player: PlayerDouble())
        model.reload()
        let before = model.state.pedals.map(\.id)

        let updated = try store.updateMetadata(id: newer.id, name: "New Name", description: "Updated.")
        model.updateExistingPedal(updated)

        #expect(model.state.pedals.map(\.id) == before)
        #expect(model.state.pedals.count == 2)
        #expect(model.state.pedals.first?.pedal.name == "New Name")
    }

    @Test func playLastWorksWhileSemanticMetadataIsPending() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let generator = ControlledMetadataGenerator()
        let store = PedalStore(directory: directory)
        let model = DapViewModel(store: store, pipeline: pipeline(generator: generator))

        model.process(cover(.blue), runID: "INTENT")
        try await waitUntil { model.pedal != nil }

        let gallery = GalleryViewModel(store: store, player: PlayerDouble())
        gallery.playLatest()

        #expect(gallery.playingID == model.pedal?.id)
    }

    private func pipeline(generator: any PedalMetadataGenerating) -> DapPipeline {
        DapPipeline(
            subjectService: SubjectDouble(result: .success(ExtractedSubject(image: cover(.blue), confidence: nil, usedFallback: false, fallbackReason: nil))),
            visionAnalyzer: ObjectDouble(result: .success(ObjectObservation(labels: ["shape"], labelConfidence: 0.5, subjectConfidence: nil, aspectRatio: 1, subjectPixelCount: 1, hasTransparency: false, material: .unknown, materialConfidence: 0))),
            generator: generator
        )
    }

    private func temporaryDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    private func cover(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 8)).image {
            color.setFill()
            $0.cgContext.fill(CGRect(x: 0, y: 0, width: 16, height: 8))
        }
    }

    private func pedal(id: UUID = UUID(), name: String, description: String, date: Date = Date(timeIntervalSince1970: 1)) -> PhotoPedal {
        PhotoPedal(id: id, name: name, description: description, sequence: PedalSequence(harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100), notes: [PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)], soundProfile: .legacy), effect: .reverb, createdAt: date, coverFilename: "latest-pedal.png")
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async throws {
        for _ in 0 ..< 100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Timed out waiting for condition")
    }
}

private actor ControlledMetadataGenerator: PedalMetadataGenerating {
    private var continuation: CheckedContinuation<PedalDraft, Error>?
    private var pendingDraft: PedalDraft?

    func generate(observation: ObjectObservation, harmony: PedalHarmony) async throws -> PedalDraft {
        if let pendingDraft {
            self.pendingDraft = nil
            return pendingDraft
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func succeed(_ draft: PedalDraft) {
        if let continuation {
            continuation.resume(returning: draft)
            self.continuation = nil
        } else {
            pendingDraft = draft
        }
    }
}

private struct ImmediateMetadataGenerator: PedalMetadataGenerating {
    let result: Result<PedalDraft, AppError>
    func generate(observation: ObjectObservation, harmony: PedalHarmony) async throws -> PedalDraft { try result.get() }
}

@MainActor
private struct SubjectDouble: SubjectExtracting {
    let result: Result<ExtractedSubject, AppError>
    let isAvailable = true
    func extract(from image: UIImage) async throws -> ExtractedSubject { try result.get() }
}

@MainActor
private struct ObjectDouble: ObjectAnalyzing {
    let result: Result<ObjectObservation, AppError>
    func analyze(image: UIImage, subject: ExtractedSubject) async throws -> ObjectObservation { try result.get() }
}

@MainActor
private final class PlayerDouble: PedalPlaying {
    private(set) var playedID: UUID?
    var stopHandler: ((DapSynthStopReason) -> Void)?
    private(set) var isPlaying = false
    func play(_ pedal: PhotoPedal) throws { playedID = pedal.id; isPlaying = true }
    func stop() { isPlaying = false }
}

import Observation
import UIKit

@MainActor
@Observable
final class PhotoPedalViewModel {
    enum SemanticEnrichmentState: Equatable {
        case notStarted
        case loading
        case succeeded
        case failed
        case cancelled
        case staleIgnored

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    var pedal: PhotoPedal?
    var cover: UIImage?
    var stage: PedalProcessingStage = .preparing
    var isProcessing = false
    var errorMessage: String?
    var selectedEffect: PedalEffect = .reverb
    var pendingPedal: PhotoPedal?
    var pendingCover: UIImage?
    var saveErrorMessage: String?
    var semanticEnrichmentState: SemanticEnrichmentState = .notStarted

    private let pipeline: PhotoPedalPipeline
    private let synth = PhotoPedalSynth()
    private var task: Task<Void, Never>?
    private var enrichmentTask: Task<Void, Never>?
    private var processingToken: UUID?
    private var enrichmentToken: UUID?

    private let store: PedalStore
    private let metadataUpdateHandler: (StoredPedal) -> Void

    convenience init() { self.init(store: .shared, pipeline: PhotoPedalPipeline()) }
    convenience init(metadataUpdateHandler: @escaping (StoredPedal) -> Void) {
        self.init(store: .shared, pipeline: PhotoPedalPipeline(), metadataUpdateHandler: metadataUpdateHandler)
    }
    convenience init(store: PedalStore, metadataUpdateHandler: @escaping (StoredPedal) -> Void = { _ in }) {
        self.init(store: store, pipeline: PhotoPedalPipeline(), metadataUpdateHandler: metadataUpdateHandler)
    }
    init(
        store: PedalStore = .shared,
        pipeline: PhotoPedalPipeline,
        metadataUpdateHandler: @escaping (StoredPedal) -> Void = { _ in }
    ) {
        self.store = store
        self.pipeline = pipeline
        self.metadataUpdateHandler = metadataUpdateHandler
    }

    func load(data: Data?, runID: String? = nil) {
        let runID = runID ?? PerformanceDiagnostics.makeRunID()
        do {
            guard let data else { throw AppError.imageDecodeFailed }
            let image = try PerformanceDiagnostics.measure("imageDecode", runID: runID, details: "dataBytes=\(data.count)") {
                guard let image = UIImage(data: data) else { throw AppError.imageDecodeFailed }
                return image
            }
            PerformanceDiagnostics.event("imageDecodeCompleted", runID: runID, details: "width=\(image.cgImage?.width ?? 0) height=\(image.cgImage?.height ?? 0) executor=main")
            process(image, runID: runID)
        } catch { errorMessage = "Não foi possível carregar esta foto." }
    }

    func process(_ image: UIImage, runID: String? = nil) {
        guard !isProcessing else { return }
        let runID = runID ?? PerformanceDiagnostics.makeRunID()
        errorMessage = nil; isProcessing = true; semanticEnrichmentState = .notStarted
        enrichmentToken = nil
        enrichmentTask?.cancel()
        let processingToken = UUID()
        self.processingToken = processingToken
        task = Task {
            defer {
                if self.processingToken == processingToken {
                    isProcessing = false
                    task = nil
                }
            }
            do {
                try await PerformanceDiagnostics.measure("totalPipeline", runID: runID, details: "inputWidth=\(image.cgImage?.width ?? 0) inputHeight=\(image.cgImage?.height ?? 0)") {
                    let result = try await pipeline.runEssential(image: image, runID: runID) { [weak self] stage in self?.stage = stage }
                    try Task.checkCancellation()
                    pendingPedal = result.pedal
                    pendingCover = result.cover
                    selectedEffect = result.pedal.effect
                    try Task.checkCancellation()
                    try savePendingResult(runID: runID)
                    try Task.checkCancellation()
                    startSemanticEnrichment(for: result, runID: runID)
                }
            } catch is CancellationError { }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func chooseEffect(_ effect: PedalEffect) {
        selectedEffect = effect
        guard let pedal, let cover else { return }
        let updated = pedal.updating(effect: effect)
        do { try store.save(updated, cover: cover); self.pedal = updated }
        catch { errorMessage = error.localizedDescription }
    }

    func updateEffectMix(_ mix: Double) {
        guard let pedal, let cover else { return }
        let profile = pedal.sequence.soundProfile.updatingMix(mix, for: selectedEffect)
        let updated = pedal.updating(soundProfile: profile)
        do { try store.save(updated, cover: cover); self.pedal = updated }
        catch { errorMessage = error.localizedDescription }
    }

    func effectMix(for effect: PedalEffect) -> Double { pedal?.sequence.soundProfile.mix(for: effect) ?? 0 }
    func play() { guard let pedal else { return }; try? synth.play(pedal) }
    func retrySave() {
        do { try savePendingResult(runID: PerformanceDiagnostics.makeRunID()) }
        catch { saveErrorMessage = error.localizedDescription }
    }

    func discardPendingResult() { pendingPedal = nil; pendingCover = nil; saveErrorMessage = nil }

    func reset() {
        processingToken = nil
        enrichmentToken = nil
        task?.cancel(); enrichmentTask?.cancel(); enrichmentTask = nil; synth.stop(); pedal = nil; cover = nil; pendingPedal = nil; pendingCover = nil; errorMessage = nil; saveErrorMessage = nil; semanticEnrichmentState = .notStarted
    }

    private func savePendingResult(runID: String) throws {
        guard let pendingPedal, let pendingCover else { return }
        PerformanceDiagnostics.signpostEvent("initialPersistence", runID: runID, details: "pedalID=\(pendingPedal.id.uuidString)")
        try PerformanceDiagnostics.measure("persistence", runID: runID, details: "coverWidth=\(pendingCover.cgImage?.width ?? 0) coverHeight=\(pendingCover.cgImage?.height ?? 0)") {
            try store.save(pendingPedal, cover: pendingCover, diagnosticsRunID: runID)
        }
        pedal = pendingPedal
        cover = pendingCover
        self.pendingPedal = nil
        self.pendingCover = nil
        saveErrorMessage = nil
        PerformanceDiagnostics.signpostEvent("resultPresented", runID: runID, details: "pedalID=\(pendingPedal.id.uuidString)")
    }

    private func startSemanticEnrichment(for result: PedalEssentialResult, runID: String) {
        let creationID = result.pedal.id
        let token = UUID()
        enrichmentToken = token
        semanticEnrichmentState = .loading
        enrichmentTask = Task { [self] in
            defer {
                if enrichmentToken == token {
                    enrichmentTask = nil
                }
            }
            do {
                let draft = try await PerformanceDiagnostics.measure("semanticEnrichment", runID: runID, details: "pedalID=\(creationID.uuidString)") {
                    try await pipeline.generateSemanticMetadata(preparedImage: result.preparedImage, harmony: result.pedal.sequence.harmony, runID: runID)
                }
                try Task.checkCancellation()
                guard enrichmentToken == token, pedal?.id == creationID else {
                    if enrichmentToken == token { semanticEnrichmentState = .staleIgnored }
                    PerformanceDiagnostics.event("semanticEnrichmentStaleIgnored", runID: runID, details: "pedalID=\(creationID.uuidString)")
                    return
                }
                let updated = try store.updateMetadata(id: creationID, name: draft.name, description: draft.description, diagnosticsRunID: runID)
                try Task.checkCancellation()
                guard enrichmentToken == token, pedal?.id == creationID else {
                    if enrichmentToken == token { semanticEnrichmentState = .staleIgnored }
                    PerformanceDiagnostics.event("semanticEnrichmentStaleIgnored", runID: runID, details: "pedalID=\(creationID.uuidString)")
                    return
                }
                pedal = updated.pedal
                semanticEnrichmentState = .succeeded
                metadataUpdateHandler(updated)
            } catch is CancellationError {
                if enrichmentToken == token {
                    semanticEnrichmentState = .cancelled
                }
                PerformanceDiagnostics.event("semanticEnrichmentCancelled", runID: runID, details: "pedalID=\(creationID.uuidString)")
            } catch {
                if enrichmentToken == token {
                    semanticEnrichmentState = .failed
                }
                PerformanceDiagnostics.event("semanticEnrichmentFailed", runID: runID, details: "pedalID=\(creationID.uuidString)")
            }
        }
    }
}

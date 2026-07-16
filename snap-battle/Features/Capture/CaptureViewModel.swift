import Observation
import UIKit

@MainActor
@Observable
final class PhotoPedalViewModel {
    var pedal: PhotoPedal?
    var cover: UIImage?
    var stage: PedalProcessingStage = .preparing
    var isProcessing = false
    var errorMessage: String?
    var selectedEffect: PedalEffect = .reverb
    var pendingPedal: PhotoPedal?
    var pendingCover: UIImage?
    var saveErrorMessage: String?

    private let pipeline = PhotoPedalPipeline()
    private let synth = PhotoPedalSynth()
    private var task: Task<Void, Never>?
    private var processingToken: UUID?

    private let store: PedalStore

    convenience init() { self.init(store: .shared) }
    init(store: PedalStore) { self.store = store }

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
        errorMessage = nil; isProcessing = true
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
                    let result = try await pipeline.run(image: image, runID: runID) { [weak self] stage in self?.stage = stage }
                    try Task.checkCancellation()
                    pendingPedal = result.pedal
                    pendingCover = result.cover
                    selectedEffect = result.pedal.effect
                    try Task.checkCancellation()
                    try savePendingResult(runID: runID)
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
        task?.cancel(); synth.stop(); pedal = nil; cover = nil; pendingPedal = nil; pendingCover = nil; errorMessage = nil; saveErrorMessage = nil
    }

    private func savePendingResult(runID: String) throws {
        guard let pendingPedal, let pendingCover else { return }
        try PerformanceDiagnostics.measure("persistence", runID: runID, details: "coverWidth=\(pendingCover.cgImage?.width ?? 0) coverHeight=\(pendingCover.cgImage?.height ?? 0)") {
            try store.save(pendingPedal, cover: pendingCover, diagnosticsRunID: runID)
        }
        pedal = pendingPedal
        cover = pendingCover
        self.pendingPedal = nil
        self.pendingCover = nil
        saveErrorMessage = nil
    }
}

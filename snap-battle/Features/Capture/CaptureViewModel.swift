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

    private let store: PedalStore

    convenience init() { self.init(store: .shared) }
    init(store: PedalStore) { self.store = store }

    func load(data: Data?) {
        do {
            guard let data, let image = UIImage(data: data) else { throw AppError.imageDecodeFailed }
            process(image)
        } catch { errorMessage = "Não foi possível carregar esta foto." }
    }

    func process(_ image: UIImage) {
        guard !isProcessing else { return }
        errorMessage = nil; isProcessing = true
        task = Task {
            defer { isProcessing = false; task = nil }
            do {
                let result = try await pipeline.run(image: image) { [weak self] stage in self?.stage = stage }
                pendingPedal = result.pedal
                pendingCover = result.cover
                selectedEffect = result.pedal.effect
                try savePendingResult()
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
        do { try savePendingResult() }
        catch { saveErrorMessage = error.localizedDescription }
    }

    func discardPendingResult() { pendingPedal = nil; pendingCover = nil; saveErrorMessage = nil }

    func reset() {
        task?.cancel(); synth.stop(); pedal = nil; cover = nil; pendingPedal = nil; pendingCover = nil; errorMessage = nil; saveErrorMessage = nil
    }

    private func savePendingResult() throws {
        guard let pendingPedal, let pendingCover else { return }
        try store.save(pendingPedal, cover: pendingCover)
        pedal = pendingPedal
        cover = pendingCover
        self.pendingPedal = nil
        self.pendingCover = nil
        saveErrorMessage = nil
    }
}

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

    private let pipeline = PhotoPedalPipeline()
    private let synth = PhotoPedalSynth()
    private var task: Task<Void, Never>?

    init() {
        if let latest = PedalStore.loadLatest() { pedal = latest.pedal; cover = latest.cover; selectedEffect = latest.pedal.effect }
    }

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
                pedal = result.pedal; cover = result.cover; selectedEffect = result.pedal.effect
                try PedalStore.save(result.pedal, cover: result.cover)
            } catch is CancellationError { }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func chooseEffect(_ effect: PedalEffect) {
        selectedEffect = effect
        guard var pedal, let cover else { return }
        pedal = PhotoPedal(id: pedal.id, name: pedal.name, description: pedal.description, sequence: pedal.sequence, effect: effect, createdAt: pedal.createdAt, coverFilename: pedal.coverFilename)
        self.pedal = pedal
        try? PedalStore.save(pedal, cover: cover)
    }

    func play() { guard let pedal else { return }; try? synth.play(pedal.sequence, effect: selectedEffect) }
    func playLast() { if pedal == nil, let latest = PedalStore.loadLatest() { pedal = latest.pedal; cover = latest.cover }; play() }
    func reset() { task?.cancel(); synth.stop(); pedal = nil; cover = nil; errorMessage = nil }
}

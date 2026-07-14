import Foundation
import Observation
import UIKit
import VisionKit

@MainActor
@Observable
final class CaptureViewModel {
    enum State: Equatable {
        case idle
        case processing(ProcessingStage)
        case completed
        case failed(AppError)
    }

    var state: State = .idle
    var result: Creature?
    var diagnostics = DebugDiagnostics()
    #if DEBUG
    var isRepeating = false
    #endif

    private let generator: any CreatureGenerating
    private let pipeline: CreaturePipeline
    private var preparedInput: PreparedImage?
    private var processingTask: Task<Void, Never>?

    init(generator: any CreatureGenerating) {
        self.generator = generator
        pipeline = CreaturePipeline(generator: generator)
        refreshEnvironmentDiagnostics()
    }

    convenience init() {
        self.init(generator: FoundationModelsCreatureGenerator())
    }

    func refreshEnvironmentDiagnostics() {
        diagnostics.activeGenerator = generator.kind
        diagnostics.modelAvailability = generator.availability()
        diagnostics.cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        diagnostics.subjectExtractionAvailable = ImageAnalyzer.isSupported
    }

    func process(_ image: UIImage) {
        guard processingTask == nil, result == nil else { return }
        refreshEnvironmentDiagnostics()
        diagnostics.currentRun = nil
        processingTask = Task { [weak self] in
            guard let self else { return }
            defer { processingTask = nil }
            do {
                let output = try await pipeline.run(with: image) { [weak self] stage in
                    self?.state = .processing(stage)
                } progress: { [weak self] run in
                    self?.diagnostics.currentRun = run
                }
                result = output.creature
                preparedInput = output.preparedInput
                diagnostics.currentRun = output.diagnostics
                diagnostics.firstRun = output.diagnostics
                diagnostics.repeatedRun = nil
                state = .completed
            } catch is CancellationError {
                state = .idle
            } catch let error as AppError {
                state = .failed(error)
            } catch {
                state = .failed(.foundationModelFailed(error.localizedDescription))
            }
        }
    }

    #if DEBUG
    func runAgainWithSameImage() {
        guard processingTask == nil, result != nil, let preparedInput else { return }
        refreshEnvironmentDiagnostics()
        diagnostics.repeatedRun = nil
        isRepeating = true
        processingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                processingTask = nil
                isRepeating = false
            }
            do {
                let output = try await pipeline.run(withPreparedImage: preparedInput) { _ in
                    // The first creature remains frozen while the diagnostic rerun executes.
                } progress: { [weak self] run in
                    self?.diagnostics.currentRun = run
                    self?.diagnostics.repeatedRun = run
                }
                diagnostics.currentRun = output.diagnostics
                diagnostics.repeatedRun = output.diagnostics
            } catch {
                // The progress callback already retains the complete stage and NSError context.
            }
        }
    }
    #endif

    func cancel() {
        processingTask?.cancel()
    }

    func reset() {
        processingTask?.cancel()
        processingTask = nil
        result = nil
        preparedInput = nil
        diagnostics.currentRun = nil
        diagnostics.firstRun = nil
        diagnostics.repeatedRun = nil
        state = .idle
        #if DEBUG
        isRepeating = false
        #endif
    }
}

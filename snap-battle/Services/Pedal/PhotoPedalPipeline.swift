import UIKit

@MainActor
final class PhotoPedalPipeline {
    private let imagePreparer: ImageInputPreparer
    private let preparationExecutor: ImagePreparationExecutor
    private let retroProcessor: any RetroImageProcessing
    private let visionAnalyzer: any ObjectAnalyzing
    private let subjectService: any SubjectExtracting
    private let generator: any PedalMetadataGenerating
    private let validator = PedalDraftValidator()

    init() {
        imagePreparer = ImageInputPreparer()
        preparationExecutor = ImagePreparationExecutor()
        retroProcessor = RetroImageProcessor()
        visionAnalyzer = VisionObjectAnalyzer()
        subjectService = SubjectExtractionService()
        generator = FoundationModelsPedalGenerator()
    }

    init(
        imagePreparer: ImageInputPreparer,
        retroProcessor: any RetroImageProcessing,
        visionAnalyzer: any ObjectAnalyzing,
        subjectService: any SubjectExtracting,
        generator: any PedalMetadataGenerating
    ) {
        self.imagePreparer = imagePreparer
        self.preparationExecutor = ImagePreparationExecutor()
        self.retroProcessor = retroProcessor
        self.visionAnalyzer = visionAnalyzer
        self.subjectService = subjectService
        self.generator = generator
    }

    convenience init(generator: any PedalMetadataGenerating) {
        self.init(imagePreparer: ImageInputPreparer(), retroProcessor: RetroImageProcessor(), visionAnalyzer: VisionObjectAnalyzer(), subjectService: SubjectExtractionService(), generator: generator)
    }

    convenience init(retroProcessor: any RetroImageProcessing) {
        self.init(imagePreparer: ImageInputPreparer(), retroProcessor: retroProcessor, visionAnalyzer: VisionObjectAnalyzer(), subjectService: SubjectExtractionService(), generator: FoundationModelsPedalGenerator())
    }

    convenience init(subjectService: any SubjectExtracting, generator: any PedalMetadataGenerating) {
        self.init(imagePreparer: ImageInputPreparer(), retroProcessor: RetroImageProcessor(), visionAnalyzer: VisionObjectAnalyzer(), subjectService: subjectService, generator: generator)
    }

    convenience init(visionAnalyzer: any ObjectAnalyzing, generator: any PedalMetadataGenerating) {
        self.init(imagePreparer: ImageInputPreparer(), retroProcessor: RetroImageProcessor(), visionAnalyzer: visionAnalyzer, subjectService: SubjectExtractionService(), generator: generator)
    }

    convenience init(subjectService: any SubjectExtracting, visionAnalyzer: any ObjectAnalyzing, generator: any PedalMetadataGenerating) {
        self.init(imagePreparer: ImageInputPreparer(), retroProcessor: RetroImageProcessor(), visionAnalyzer: visionAnalyzer, subjectService: subjectService, generator: generator)
    }

    func run(image: UIImage, runID: String? = nil, stage: @escaping (PedalProcessingStage) -> Void) async throws -> (pedal: PhotoPedal, cover: UIImage) {
        let runID = runID ?? PerformanceDiagnostics.makeRunID()
        stage(.preparing)
        try Task.checkCancellation()
        let input = try imagePreparer.makePixelBuffer(from: image)
        let preparedValue = try await PerformanceDiagnostics.measure("imagePreparation", runID: runID, details: "inputWidth=\(input.buffer.width) inputHeight=\(input.buffer.height) executor=imagePreparation") {
            try await preparationExecutor.prepare(input, runID: runID)
        }
        let preparedImage = try imagePreparer.materialize(preparedValue)
        let prepared = PreparedImage(image: preparedImage, originalSize: preparedValue.originalSize,
                                     processedSize: preparedValue.processedSize, fingerprint: preparedValue.fingerprint)
        try Task.checkCancellation()
        stage(.makingCover)
        let cover = try await PerformanceDiagnostics.measure("retroProcessing", runID: runID, details: "inputWidth=\(prepared.processedSize.width) inputHeight=\(prepared.processedSize.height)") {
            try await retroProcessor.process(prepared.image)
        }
        let color = try PerformanceDiagnostics.measure("colorAnalysis", runID: runID, details: "analysisSide=\(PedalHeuristics.analysisSide)") {
            try PhotoColorAnalyzer.analyze(prepared.image)
        }
        let sequence = try PerformanceDiagnostics.measure("sequenceGeneration", runID: runID, details: "coverWidth=\(cover.cgImage?.width ?? 0) coverHeight=\(cover.cgImage?.height ?? 0)") {
            try ImageSequenceGenerator.makeSequence(retroImage: cover, colorProfile: color)
        }
        try Task.checkCancellation()
        stage(.naming)
        let subject: ExtractedSubject
        do {
            subject = try await PerformanceDiagnostics.measure("subjectExtraction", runID: runID) {
                try await subjectService.extract(from: prepared.image)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            subject = ExtractedSubject(image: prepared.image, confidence: nil, usedFallback: true, fallbackReason: error.localizedDescription)
        }

        let draft: PedalDraft
        do {
            let observation = try await PerformanceDiagnostics.measure("objectAnalysis", runID: runID) {
                try await visionAnalyzer.analyze(image: prepared.image, subject: subject)
            }
            let generated = try await PerformanceDiagnostics.measure("metadataGeneration", runID: runID) {
                try await generator.generate(observation: observation, harmony: sequence.harmony)
            }
            draft = try PerformanceDiagnostics.measure("metadataValidation", runID: runID) {
                try validator.validate(generated)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            draft = try validator.validate(PedalDraft(name: "Photo Pedal", description: "A photo-generated sound pedal."))
        }
        let pedal = PhotoPedal(id: UUID(), name: draft.name, description: draft.description, sequence: sequence, effect: .reverb, createdAt: .now, coverFilename: "latest-pedal.png")
        return (pedal, cover)
    }
}

protocol PedalMetadataGenerating: Sendable {
    func generate(observation: ObjectObservation, harmony: PedalHarmony) async throws -> PedalDraft
}

enum PedalProcessingStage: String, Equatable {
    case preparing = "Preparando foto"
    case makingCover = "Criando pedal 2-bit"
    case naming = "Dando nome ao pedal"
}

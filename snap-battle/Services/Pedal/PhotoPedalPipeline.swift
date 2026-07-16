import UIKit

@MainActor
final class PhotoPedalPipeline {
    private let imagePreparer: ImageInputPreparer
    private let retroProcessor: any RetroImageProcessing
    private let visionAnalyzer: any ObjectAnalyzing
    private let subjectService: any SubjectExtracting
    private let generator: any PedalMetadataGenerating
    private let validator = PedalDraftValidator()

    init() {
        imagePreparer = ImageInputPreparer()
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

    func run(image: UIImage, stage: @escaping (PedalProcessingStage) -> Void) async throws -> (pedal: PhotoPedal, cover: UIImage) {
        stage(.preparing)
        let prepared = try imagePreparer.prepare(image)
        try Task.checkCancellation()
        stage(.makingCover)
        let cover = try await retroProcessor.process(prepared.image)
        let color = try PhotoColorAnalyzer.analyze(prepared.image)
        let sequence = try ImageSequenceGenerator.makeSequence(retroImage: cover, colorProfile: color)
        try Task.checkCancellation()
        stage(.naming)
        let subject: ExtractedSubject
        do {
            subject = try await subjectService.extract(from: prepared.image)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            subject = ExtractedSubject(image: prepared.image, confidence: nil, usedFallback: true, fallbackReason: error.localizedDescription)
        }

        let draft: PedalDraft
        do {
            let observation = try await visionAnalyzer.analyze(image: prepared.image, subject: subject)
            let generated = try await generator.generate(observation: observation, harmony: sequence.harmony)
            draft = try validator.validate(generated)
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

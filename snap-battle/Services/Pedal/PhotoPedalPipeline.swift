import UIKit

@MainActor
final class PhotoPedalPipeline {
    private let imagePreparer = ImageInputPreparer()
    private let retroProcessor: any RetroImageProcessing = RetroImageProcessor()
    private let visionAnalyzer: any ObjectAnalyzing = VisionObjectAnalyzer()
    private let subjectService: any SubjectExtracting = SubjectExtractionService()
    private let generator = FoundationModelsPedalGenerator()
    private let validator = PedalDraftValidator()

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
        let subject = try await subjectService.extract(from: prepared.image)
        let observation = try await visionAnalyzer.analyze(image: prepared.image, subject: subject)
        let draft = try validator.validate(try await generator.generate(observation: observation, harmony: sequence.harmony))
        let pedal = PhotoPedal(id: UUID(), name: draft.name, description: draft.description, sequence: sequence, effect: .reverb, createdAt: .now, coverFilename: "latest-pedal.png")
        return (pedal, cover)
    }
}

enum PedalProcessingStage: String, Equatable {
    case preparing = "Preparando foto"
    case makingCover = "Criando pedal 2-bit"
    case naming = "Dando nome ao pedal"
}

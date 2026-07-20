import Foundation
import UIKit
import VisionKit

struct ExtractedSubject: Sendable {
    let image: UIImage
    let confidence: Double?
    let usedFallback: Bool
    let fallbackReason: String?
    let subjectCount: Int?

    init(image: UIImage, confidence: Double?, usedFallback: Bool, fallbackReason: String? = nil, subjectCount: Int? = nil) {
        self.image = image
        self.confidence = confidence
        self.usedFallback = usedFallback
        self.fallbackReason = fallbackReason
        self.subjectCount = subjectCount
    }
}

@MainActor
final class SubjectExtractionService: SubjectExtracting {
    let isAvailable = ImageAnalyzer.isSupported
    private let analyzer = ImageAnalyzer()
    private let configuration = ImageAnalyzer.Configuration(.visualLookUp)
    private var interaction = ImageAnalysisInteraction()

    func extract(from image: UIImage) async throws -> ExtractedSubject {
        try Task.checkCancellation()
        guard isAvailable else { return ExtractedSubject(image: image, confidence: nil, usedFallback: true, fallbackReason: "ImageAnalyzer.isSupported is false on this device.") }
        do {
            interaction.preferredInteractionTypes = .imageSubject
            let analysis = try await analyzer.analyze(image, configuration: configuration)
            try Task.checkCancellation()
            interaction.analysis = analysis
            let subjects = await interaction.subjects
            guard let subject = subjects.first else {
                return ExtractedSubject(image: image, confidence: nil, usedFallback: true, fallbackReason: "VisionKit completed without returning an image subject.", subjectCount: subjects.count)
            }
            return ExtractedSubject(image: try await subject.image, confidence: nil, usedFallback: false, subjectCount: subjects.count)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let nsError = error as NSError
            return ExtractedSubject(image: image, confidence: nil, usedFallback: true, fallbackReason: "\(String(reflecting: type(of: error))): \(nsError.localizedDescription) [domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)]")
        }
    }
}

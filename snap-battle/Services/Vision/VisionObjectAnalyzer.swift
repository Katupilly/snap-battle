import Foundation
import UIKit
import Vision

struct VisionObjectAnalyzer: Sendable, ObjectAnalyzing {
    func analyze(image: UIImage, subject: ExtractedSubject) async throws -> ObjectObservation {
        try Task.checkCancellation()
        guard let cgImage = image.cgImage else { throw AppError.imageDecodeFailed }
        let request = ClassifyImageRequest()
        let observations = try await request.perform(on: cgImage)
        try Task.checkCancellation()
        let top = observations.sorted { $0.confidence > $1.confidence }.prefix(5)
        let labels = top.map(\.identifier)
        let labelConfidences = top.map { Double($0.confidence) }
        let labelConfidence = Double(top.first?.confidence ?? 0)
        let aspectRatio = max(image.size.width, 1) / max(image.size.height, 1)
        let subjectPixels = Int((subject.image.size.width * subject.image.scale) * (subject.image.size.height * subject.image.scale))
        let hasTransparency = subject.image.cgImage.map { image in
            image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst
        } ?? false
        let material = inferMaterial(from: labels)
        return ObjectObservation(labels: labels, labelConfidences: labelConfidences, labelConfidence: labelConfidence, subjectConfidence: subject.confidence, aspectRatio: aspectRatio, subjectPixelCount: subjectPixels, hasTransparency: hasTransparency, material: material.value, materialConfidence: material.confidence)
    }

    private func inferMaterial(from labels: [String]) -> (value: CreatureMaterial, confidence: Double) {
        let normalized = labels.map(ObjectObservation.normalize)
        let rules: [(CreatureMaterial, [String])] = [
            (.metallic, ["metal", "metallic", "steel", "iron"]),
            (.stone, ["stone", "rock", "marble"]),
            (.aquatic, ["water", "fish", "ocean"]),
            (.botanical, ["plant", "flower", "tree", "leaf"]),
            (.textile, ["cloth", "fabric", "wool"]),
            (.organic, ["animal", "bird", "dog", "cat", "person"])
        ]
        guard let match = rules.first(where: { _, terms in normalized.contains(where: { label in terms.contains(where: label.contains) }) }) else { return (.unknown, 0) }
        return (match.0, 0.35)
    }
}

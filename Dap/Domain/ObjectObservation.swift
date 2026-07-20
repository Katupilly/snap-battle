import Foundation

struct ObjectObservation: Equatable, Sendable {
    // Direct Vision output: top classification identifiers and confidence.
    let labels: [String]
    let labelConfidences: [Double]
    let labelConfidence: Double
    // VisionKit does not expose a calibrated subject confidence here; unknown is valid.
    let subjectConfidence: Double?
    // Derived from image geometry, not a real-world measurement.
    let aspectRatio: Double
    let subjectPixelCount: Int
    let hasTransparency: Bool
    // Heuristic mapping from Vision labels; never a physical material claim.
    let material: CreatureMaterial
    let materialConfidence: Double

    init(
        labels: [String],
        labelConfidences: [Double] = [],
        labelConfidence: Double,
        subjectConfidence: Double?,
        aspectRatio: Double,
        subjectPixelCount: Int,
        hasTransparency: Bool,
        material: CreatureMaterial,
        materialConfidence: Double
    ) {
        self.labels = labels
        self.labelConfidences = labelConfidences.isEmpty
            ? labels.enumerated().map { $0.offset == 0 ? labelConfidence : 0 }
            : labelConfidences
        self.labelConfidence = labelConfidence
        self.subjectConfidence = subjectConfidence
        self.aspectRatio = aspectRatio
        self.subjectPixelCount = subjectPixelCount
        self.hasTransparency = hasTransparency
        self.material = material
        self.materialConfidence = materialConfidence
    }

    var rankedLabels: [(label: String, confidence: Double)] {
        labels.enumerated().map { index, label in
            (label, labelConfidences.indices.contains(index) ? labelConfidences[index] : 0)
        }
    }

    var normalizedLabels: [String] { labels.map(Self.normalize).sorted() }

    var promptRepresentation: String {
        let labelText = normalizedLabels.isEmpty ? "unknown" : normalizedLabels.joined(separator: ", ")
        let subjectText = subjectConfidence.map { String(format: "%.2f", $0) } ?? "unknown"
        return "labels=[\(labelText)]; labelConfidence=\(String(format: "%.2f", labelConfidence)); subjectConfidence=\(subjectText); aspectRatio=\(String(format: "%.2f", aspectRatio)); material=\(material.rawValue); materialConfidence=\(String(format: "%.2f", materialConfidence))"
    }

    nonisolated static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

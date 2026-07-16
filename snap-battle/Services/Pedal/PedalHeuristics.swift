import Foundation

enum PedalHeuristics {
    static let analysisSide = 64
    static let minimumSaturationForHue = 0.10
    static let lowHueVarianceDegrees = 30.0
    static let highHueVarianceDegrees = 70.0
    static let significantToneFraction = 0.05
    static let edgeGradientThreshold = 0.18
    static let lowEdgeDensity = 0.03
    static let highEdgeDensity = 0.25
    static let shortGate = 0.25
    static let longGate = 0.98
    static let brightLuminance = 0.65
    static let darkLuminance = 0.35
    static let minimumReverbMix = 22.0
    static let maximumReverbMix = 78.0
    static let minimumDistortionMix = 18.0
    static let maximumDistortionMix = 75.0

    static func normalizedEdgeDensity(_ density: Double) -> Double {
        ((density - lowEdgeDensity) / (highEdgeDensity - lowEdgeDensity)).clamped(to: 0 ... 1)
    }

    static func gate(for edgeDensity: Double) -> Double {
        longGate + (shortGate - longGate) * normalizedEdgeDensity(edgeDensity)
    }

    static func reverbMix(for luminance: Double) -> Double {
        maximumReverbMix + (minimumReverbMix - maximumReverbMix) * luminance.clamped(to: 0 ... 1)
    }

    static func distortionMix(for edgeDensity: Double) -> Double {
        minimumDistortionMix + (maximumDistortionMix - minimumDistortionMix) * normalizedEdgeDensity(edgeDensity)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}

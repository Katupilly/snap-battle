import CoreGraphics
import UIKit

enum ImageSequenceGenerator {
    static func makeSequence(retroImage: UIImage, colorProfile: PhotoColorProfile) throws -> PedalSequence {
        let analysis = try analyzeTones(in: retroImage)
        let harmony = PedalHarmony(rootPitchClass: min(11, max(0, Int((colorProfile.hue / 360 * 12).rounded(.down)))), scale: scale(for: colorProfile), bpm: min(140, max(70, Int((70 + colorProfile.luminance * 70).rounded()))))
        let soundProfile = makeSoundProfile(color: colorProfile, significantToneCount: analysis.significantToneCount)
        var notes: [PedalNote] = []
        for row in 0 ..< PedalSequence.rows {
            for step in 0 ..< PedalSequence.steps {
                let level = analysis.gridLevels[row * PedalSequence.steps + step]
                guard level > 0 else { continue }
                notes.append(PedalNote(step: step, row: row, midiNote: 60 + harmony.rootPitchClass + pitchOffset(row: row, scale: harmony.scale, octaveRange: soundProfile.octaveRange), velocity: Float(level) / 3))
            }
        }
        return PedalSequence(harmony: harmony, notes: notes, soundProfile: soundProfile)
    }

    static func scale(for color: PhotoColorProfile) -> PedalScale {
        if color.hueVarianceDegrees > PedalHeuristics.highHueVarianceDegrees { return .wholeTone }
        if color.hueVarianceDegrees >= PedalHeuristics.lowHueVarianceDegrees { return .dorian }
        return color.saturation >= 0.45 ? .majorPentatonic : .minorPentatonic
    }

    static func octaveRange(for significantToneCount: Int) -> Double {
        switch significantToneCount { case 4...: 2; case 3: 1.5; default: 1 }
    }

    static func significantToneCount(in retroImage: UIImage) throws -> Int {
        try analyzeTones(in: retroImage).significantToneCount
    }

    private static func makeSoundProfile(color: PhotoColorProfile, significantToneCount: Int) -> PedalSoundProfile {
        let reverbPreset: PedalReverbPreset = color.luminance >= PedalHeuristics.brightLuminance ? .smallRoom : (color.luminance <= PedalHeuristics.darkLuminance ? .cathedral : .mediumRoom)
        let distortionPreset: PedalDistortionPreset = color.edgeDensity >= PedalHeuristics.highEdgeDensity ? .drumsBitBrush : .multiEcho1
        let reverbMix = PedalHeuristics.reverbMix(for: color.luminance), distortionMix = PedalHeuristics.distortionMix(for: color.edgeDensity)
        return PedalSoundProfile(gate: PedalHeuristics.gate(for: color.edgeDensity), octaveRange: octaveRange(for: significantToneCount), waveform: (color.hue >= 90 && color.hue < 300) ? .square : .triangle, reverbPreset: reverbPreset, distortionPreset: distortionPreset, defaultReverbMix: reverbMix, defaultDistortionMix: distortionMix, reverbMix: reverbMix, distortionMix: distortionMix)
    }

    private static func pitchOffset(row: Int, scale: PedalScale, octaveRange: Double) -> Int {
        let reversedRow = PedalSequence.rows - 1 - row
        let chromaticSpan = Int((12 * octaveRange).rounded())
        let target = Double(reversedRow) / Double(PedalSequence.rows - 1) * Double(chromaticSpan)
        let candidates = (0 ... Int(ceil(octaveRange))).flatMap { octave in scale.degrees.map { $0 + octave * 12 } }
        return candidates.min(by: { abs(Double($0) - target) < abs(Double($1) - target) }) ?? 0
    }

    private static func analyzeTones(in image: UIImage) throws -> (gridLevels: [Int], significantToneCount: Int) {
        guard let cgImage = image.cgImage else { throw AppError.imageDecodeFailed }
        let fullLevels = try toneLevels(cgImage, width: cgImage.width, height: cgImage.height)
        let counts = (0 ... 3).map { level in fullLevels.filter { $0 == level }.count }
        let significantCount = counts.filter { Double($0) / Double(fullLevels.count) >= PedalHeuristics.significantToneFraction }.count
        return (try toneLevels(cgImage, width: PedalSequence.steps, height: PedalSequence.rows), significantCount)
    }

    private static func toneLevels(_ image: CGImage, width: Int, height: Int) throws -> [Int] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw AppError.imageDecodeFailed }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (0 ..< width * height).map { index in
            let offset = index * 4
            let luminance = 0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1]) + 0.0722 * Double(pixels[offset + 2])
            return min(3, max(0, Int((luminance / 256 * 4).rounded(.down))))
        }
    }
}

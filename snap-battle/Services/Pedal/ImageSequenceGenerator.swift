import CoreGraphics
import UIKit

enum ImageSequenceGenerator {
    static func makeSequence(retroImage: UIImage, colorProfile: PhotoColorProfile) throws -> PedalSequence {
        let levels = try toneLevels(in: retroImage)
        let root = min(11, max(0, Int((colorProfile.hue / 360 * 12).rounded(.down))))
        let scale: PedalScale = colorProfile.saturation >= 0.45 ? .majorPentatonic : .minorPentatonic
        let bpm = min(140, max(70, Int((70 + colorProfile.luminance * 70).rounded())))
        let harmony = PedalHarmony(rootPitchClass: root, scale: scale, bpm: bpm)
        var notes: [PedalNote] = []
        for row in 0 ..< PedalSequence.rows {
            for step in 0 ..< PedalSequence.steps {
                let level = levels[row * PedalSequence.steps + step]
                guard level > 0 else { continue }
                let pitchRow = PedalSequence.rows - 1 - row
                notes.append(PedalNote(step: step, row: row, midiNote: 60 + root + scale.intervals[pitchRow], velocity: Float(level) / 3))
            }
        }
        return PedalSequence(harmony: harmony, notes: notes)
    }

    private static func toneLevels(in image: UIImage) throws -> [Int] {
        guard let cgImage = image.cgImage else { throw AppError.imageDecodeFailed }
        let width = PedalSequence.steps, height = PedalSequence.rows
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw AppError.imageDecodeFailed }
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (0 ..< width * height).map { index in
            let offset = index * 4
            let luminance = 0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1]) + 0.0722 * Double(pixels[offset + 2])
            return min(3, max(0, Int((luminance / 256 * 4).rounded(.down))))
        }
    }
}

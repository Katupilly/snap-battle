import CoreGraphics
import Foundation
import UIKit

/// Pure, deterministic analyzer that produces a `VisualAnalysis` from
/// a `PreparedImage`. See
/// `specs/current/photo-midi-variety-v2.md` §12.6 and
/// `specs/current/photo-midi-variety-v2-incremento-2.md` §6.2.
///
/// The analyzer is intentionally a `Sendable` enum with a single
/// `static` function. It reuses the same 64×64 RGBA buffer already
/// produced for `PhotoColorAnalyzer.analyze(_:side:)` so the visual
/// descriptors add **no second full pass** over the prepared pixels
/// when called by the production pipeline.
///
/// Determinism contract (per design §12.4 and Increment 2 §8.1):
///
/// - No `Date()`, `UUID()`, RNG, `Swift.Hasher`, `hashValue`.
/// - No iteration over unordered `Dictionary` or `Set`.
/// - Histograms use fixed-size `Array` with explicit indices.
/// - Result is `Equatable`; the same `PreparedImage` produces the
///   same `VisualAnalysis` on every run and on every platform.
enum VisualAnalyzer {
    /// Number of bins for each histogram. Exposed via `PedalHeuristics`
    /// so the analyzer and its tests share a single source of truth.
    static let hueBinCount = 12
    static let luminanceBinCount = 8
    static let saturationBinCount = 4

    /// Compute the full `VisualAnalysis` from a `PreparedImage`.
    ///
    /// The function takes the `PreparedImage` (the same wrapper
    /// consumed by `PhotoColorAnalyzer` and `ImageSequenceGenerator`)
    /// and returns a fully determined analysis. It is pure: the same
    /// `PreparedImage` → the same `VisualAnalysis`, every time.
    ///
    /// The implementation re-renders the 64×64 RGBA buffer once and
    /// computes every descriptor in a single pass: histograms, mean
    /// luminance, mean saturation, mean RGB, hue variance, edge
    /// density, quadrant energy, visual entropy, and standard
    /// deviation. The downstream `PhotoColorProfile` is reconstructed
    /// from the same intermediate data — there is no second pass over
    /// the pixel buffer.
    static func analyze(preparedImage: PreparedImage) throws -> VisualAnalysis {
        let side = PedalHeuristics.analysisSide
        let pixels = try rgbaPixels(from: preparedImage.image, side: side)
        return try analyze(rgba: pixels, side: side, fingerprint: preparedImage.fingerprint)
    }

    /// Analyze a 64×64 RGBA buffer directly. Exposed for tests and
    /// for callers that already have the buffer.
    static func analyze(rgba: [UInt8], side: Int, fingerprint: String) throws -> VisualAnalysis {
        precondition(rgba.count == side * side * 4, "expected \(side * side * 4) bytes, got \(rgba.count)")
        let pixels = rgba

        var hueBins = [Int](repeating: 0, count: hueBinCount)
        var luminanceBins = [Int](repeating: 0, count: luminanceBinCount)
        var saturationBins = [Int](repeating: 0, count: saturationBinCount)
        var topLeftLuminance = 0.0, topRightLuminance = 0.0, bottomLeftLuminance = 0.0, bottomRightLuminance = 0.0
        var topLeftCount = 0, topRightCount = 0, bottomLeftCount = 0, bottomRightCount = 0
        var hueCount = 0
        var luminanceSum = 0.0
        var luminanceSquaredSum = 0.0
        var saturationSum = 0.0
        var hueSineSum = 0.0
        var hueCosineSum = 0.0
        var redSum = 0.0, greenSum = 0.0, blueSum = 0.0
        var alphaWeight = 0.0
        var grayscale = [Double](repeating: 0, count: side * side)

        let halfSide = side / 2
        let luminanceBinScale = Double(luminanceBinCount)
        let saturationBinScale = Double(saturationBinCount)
        let hueBinScale = 360.0 / Double(hueBinCount)

        for index in 0 ..< side * side {
            let offset = index * 4
            let alphaByte = pixels[offset + 3]
            let alpha = Double(alphaByte) / 255
            let r = Double(pixels[offset]) / 255
            let g = Double(pixels[offset + 1]) / 255
            let b = Double(pixels[offset + 2]) / 255
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            grayscale[index] = luminance
            luminanceSum += luminance
            luminanceSquaredSum += luminance * luminance
            alphaWeight += alpha
            redSum += r * alpha
            greenSum += g * alpha
            blueSum += b * alpha

            let maxChannel = max(r, g, b)
            let minChannel = min(r, g, b)
            let channelDelta = maxChannel - minChannel
            let pixelSaturation = maxChannel == 0 ? 0 : channelDelta / maxChannel
            saturationSum += alpha * pixelSaturation

            let luminanceBin = min(luminanceBinCount - 1, max(0, Int(luminance * luminanceBinScale)))
            luminanceBins[luminanceBin] += 1

            if alphaByte > 0 {
                let hsb = hsb(red: r, green: g, blue: b)
                let saturationBin = min(saturationBinCount - 1, max(0, Int(hsb.saturation * saturationBinScale)))
                saturationBins[saturationBin] += 1
                if hsb.saturation >= PedalHeuristics.minimumSaturationForHue {
                    let hueBin = min(hueBinCount - 1, max(0, Int(hsb.hue / hueBinScale)))
                    hueBins[hueBin] += 1
                    hueCount += 1
                    hueSineSum += sin(hsb.hue * .pi / 180)
                    hueCosineSum += cos(hsb.hue * .pi / 180)
                }
            }

            let x = index % side
            let y = index / side
            if y < halfSide {
                if x < halfSide { topLeftLuminance += luminance; topLeftCount += 1 }
                else { topRightLuminance += luminance; topRightCount += 1 }
            } else {
                if x < halfSide { bottomLeftLuminance += luminance; bottomLeftCount += 1 }
                else { bottomRightLuminance += luminance; bottomRightCount += 1 }
            }
        }

        let totalPixels = Double(side * side)
        let normalizedLuminance = luminanceBins.map { Double($0) / totalPixels }
        let normalizedHue = hueBins.map { Double($0) / max(1.0, Double(hueCount)) }
        let normalizedSaturation = saturationBins.map { Double($0) / totalPixels }

        let entropy = shannonEntropy(normalizedLuminance)
        let meanLum = totalPixels > 0 ? luminanceSum / totalPixels : 0
        let meanSat = totalPixels > 0 ? saturationSum / totalPixels : 0
        let variance = totalPixels > 0 ? max(0, luminanceSquaredSum / totalPixels - meanLum * meanLum) : 0
        let contrast = sqrt(variance)
        let edgeDensity = sobelEdgeDensity(grayscale, width: side, height: side)

        let topLeftEnergy = topLeftCount > 0 ? topLeftLuminance / Double(topLeftCount) : 0
        let topRightEnergy = topRightCount > 0 ? topRightLuminance / Double(topRightCount) : 0
        let bottomLeftEnergy = bottomLeftCount > 0 ? bottomLeftLuminance / Double(bottomLeftCount) : 0
        let bottomRightEnergy = bottomRightCount > 0 ? bottomRightLuminance / Double(bottomRightCount) : 0

        let topSum = topLeftEnergy + topRightEnergy
        let bottomSum = bottomLeftEnergy + bottomRightEnergy
        let leftSum = topLeftEnergy + bottomLeftEnergy
        let rightSum = topRightEnergy + bottomRightEnergy
        let verticalBalance = bottomSum > 0 ? topSum / bottomSum : 0
        let horizontalBalance = rightSum > 0 ? leftSum / rightSum : 0

        let meanR = alphaWeight > 0 ? redSum / alphaWeight : 0
        let meanG = alphaWeight > 0 ? greenSum / alphaWeight : 0
        let meanB = alphaWeight > 0 ? blueSum / alphaWeight : 0
        let meanHSB = hsb(red: meanR, green: meanG, blue: meanB)
        let meanLuminanceFromRGB = 0.2126 * meanR + 0.7152 * meanG + 0.0722 * meanB
        let hueVariance = circularHueVariance(fromSine: hueSineSum, cosine: hueCosineSum, count: hueCount)

        let colorProfile = PhotoColorProfile(
            hue: meanHSB.hue,
            saturation: meanHSB.saturation,
            luminance: meanLuminanceFromRGB,
            hueVarianceDegrees: hueVariance,
            edgeDensity: edgeDensity
        )

        return VisualAnalysis(
            colorProfile: colorProfile,
            fingerprint: fingerprint,
            hueHistogram: normalizedHue,
            luminanceHistogram: normalizedLuminance,
            saturationHistogram: normalizedSaturation,
            meanLuminance: meanLum,
            meanSaturation: meanSat,
            luminanceContrast: contrast,
            edgeDensity: edgeDensity,
            spatialEnergy: .init(
                topLeft: topLeftEnergy,
                topRight: topRightEnergy,
                bottomLeft: bottomLeftEnergy,
                bottomRight: bottomRightEnergy
            ),
            verticalBalance: verticalBalance,
            horizontalBalance: horizontalBalance,
            subjectPresence: 0.0,
            visualEntropy: entropy
        )
    }

    // MARK: - Internals

    /// Render a 64×64 RGBA8 buffer with the same orientation/color
    /// contract as `PhotoColorAnalyzer.rgbaPixels(from:side:)`.
    private static func rgbaPixels(from image: UIImage, side: Int) throws -> [UInt8] {
        guard let cgImage = image.cgImage, side > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw AppError.imageDecodeFailed }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = pixels.withUnsafeMutableBytes({
            CGContext(data: $0.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }) else { throw AppError.imageDecodeFailed }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        return pixels
    }

    private static func hsb(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double) {
        let maximum = max(red, green, blue), minimum = min(red, green, blue), delta = maximum - minimum
        let hue: Double
        if delta == 0 { hue = 0 }
        else if maximum == red { hue = (60 * ((green - blue) / delta) + 360).truncatingRemainder(dividingBy: 360) }
        else if maximum == green { hue = 60 * ((blue - red) / delta + 2) }
        else { hue = 60 * ((red - green) / delta + 4) }
        return (hue, maximum == 0 ? 0 : delta / maximum)
    }

    private static func shannonEntropy(_ histogram: [Double]) -> Double {
        var sum = 0.0
        for probability in histogram where probability > 0 {
            sum += probability * log2(probability)
        }
        return -sum
    }

    private static func sobelEdgeDensity(_ grayscale: [Double], width: Int, height: Int) -> Double {
        guard width >= 3, height >= 3, grayscale.count == width * height else { return 0 }
        var edges = 0
        var count = 0
        let threshold = PedalHeuristics.edgeGradientThreshold
        for y in 1 ..< height - 1 {
            let rowAbove = (y - 1) * width
            let rowCurrent = y * width
            let rowBelow = (y + 1) * width
            for x in 1 ..< width - 1 {
                let gx = -grayscale[rowAbove + x - 1] + grayscale[rowAbove + x + 1]
                    - 2 * grayscale[rowCurrent + x - 1] + 2 * grayscale[rowCurrent + x + 1]
                    - grayscale[rowBelow + x - 1] + grayscale[rowBelow + x + 1]
                let gy = -grayscale[rowAbove + x - 1] - 2 * grayscale[rowAbove + x] - grayscale[rowAbove + x + 1]
                    + grayscale[rowBelow + x - 1] + 2 * grayscale[rowBelow + x] + grayscale[rowBelow + x + 1]
                if sqrt(gx * gx + gy * gy) >= threshold { edges += 1 }
                count += 1
            }
        }
        return count == 0 ? 0 : Double(edges) / Double(count)
    }

    /// Circular variance of hue computed from pre-aggregated
    /// sine/cosine sums. Equivalent to
    /// `PhotoColorAnalyzer.circularVarianceDegrees(_:)` but
    /// operates on a single sum rather than an array.
    private static func circularHueVariance(fromSine sineSum: Double, cosine cosineSum: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        let sinMean = sineSum / Double(count)
        let cosMean = cosineSum / Double(count)
        let resultant = min(1, sqrt(sinMean * sinMean + cosMean * cosMean))
        return sqrt(max(0, -2 * log(max(resultant, 0.000_001)))) * 180 / .pi
    }
}

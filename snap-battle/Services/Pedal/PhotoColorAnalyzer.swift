import CoreGraphics
import UIKit

struct PhotoColorProfile: Sendable, Equatable {
    let hue: Double
    let saturation: Double
    let luminance: Double
    let hueVarianceDegrees: Double
    let edgeDensity: Double
}

enum PhotoColorAnalyzer {
    static func analyze(_ image: UIImage, side: Int = PedalHeuristics.analysisSide) throws -> PhotoColorProfile {
        let pixels = try rgbaPixels(from: image, side: side)
        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        var hues: [Double] = [], grayscale = [Double](repeating: 0, count: side * side)
        for index in 0 ..< side * side {
            let offset = index * 4, alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0 else { continue }
            let r = Double(pixels[offset]) / 255, g = Double(pixels[offset + 1]) / 255, b = Double(pixels[offset + 2]) / 255
            red += r * alpha; green += g * alpha; blue += b * alpha; weight += alpha
            grayscale[index] = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let hsb = hsb(red: r, green: g, blue: b)
            if hsb.saturation >= PedalHeuristics.minimumSaturationForHue { hues.append(hsb.hue) }
        }
        guard weight > 0 else { return PhotoColorProfile(hue: 0, saturation: 0, luminance: 0, hueVarianceDegrees: 0, edgeDensity: 0) }
        red /= weight; green /= weight; blue /= weight
        let mean = hsb(red: red, green: green, blue: blue)
        return PhotoColorProfile(hue: mean.hue, saturation: mean.saturation, luminance: 0.2126 * red + 0.7152 * green + 0.0722 * blue, hueVarianceDegrees: circularVarianceDegrees(hues), edgeDensity: sobelEdgeDensity(grayscale, width: side, height: side))
    }

    static func circularVarianceDegrees(_ hues: [Double]) -> Double {
        guard !hues.isEmpty else { return 0 }
        let sinMean = hues.map { sin($0 * .pi / 180) }.reduce(0, +) / Double(hues.count)
        let cosMean = hues.map { cos($0 * .pi / 180) }.reduce(0, +) / Double(hues.count)
        let resultant = min(1, sqrt(sinMean * sinMean + cosMean * cosMean))
        return sqrt(max(0, -2 * log(max(resultant, 0.000_001)))) * 180 / .pi
    }

    static func sobelEdgeDensity(_ grayscale: [Double], width: Int, height: Int) -> Double {
        guard width >= 3, height >= 3, grayscale.count == width * height else { return 0 }
        var edges = 0, count = 0
        for y in 1 ..< height - 1 {
            for x in 1 ..< width - 1 {
                let i = y * width + x
                let gx = -grayscale[i - width - 1] + grayscale[i - width + 1] - 2 * grayscale[i - 1] + 2 * grayscale[i + 1] - grayscale[i + width - 1] + grayscale[i + width + 1]
                let gy = -grayscale[i - width - 1] - 2 * grayscale[i - width] - grayscale[i - width + 1] + grayscale[i + width - 1] + 2 * grayscale[i + width] + grayscale[i + width + 1]
                if sqrt(gx * gx + gy * gy) >= PedalHeuristics.edgeGradientThreshold { edges += 1 }
                count += 1
            }
        }
        return count == 0 ? 0 : Double(edges) / Double(count)
    }

    private static func rgbaPixels(from image: UIImage, side: Int) throws -> [UInt8] {
        guard let cgImage = image.cgImage, side > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw AppError.imageDecodeFailed }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw AppError.imageDecodeFailed }
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
}

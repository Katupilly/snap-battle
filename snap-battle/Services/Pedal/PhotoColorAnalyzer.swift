import CoreGraphics
import UIKit

struct PhotoColorProfile: Sendable, Equatable {
    let hue: Double
    let saturation: Double
    let luminance: Double
}

enum PhotoColorAnalyzer {
    static func analyze(_ image: UIImage, side: Int = 48) throws -> PhotoColorProfile {
        guard let cgImage = image.cgImage, side > 0 else { throw AppError.imageDecodeFailed }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw AppError.imageDecodeFailed }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0 else { continue }
            red += Double(pixels[offset]) / 255 * alpha
            green += Double(pixels[offset + 1]) / 255 * alpha
            blue += Double(pixels[offset + 2]) / 255 * alpha
            weight += alpha
        }
        guard weight > 0 else { return PhotoColorProfile(hue: 0, saturation: 0, luminance: 0) }
        red /= weight; green /= weight; blue /= weight
        let maximum = max(red, green, blue), minimum = min(red, green, blue), delta = maximum - minimum
        let hue: Double
        if delta == 0 { hue = 0 }
        else if maximum == red { hue = (60 * ((green - blue) / delta) + 360).truncatingRemainder(dividingBy: 360) }
        else if maximum == green { hue = 60 * ((blue - red) / delta + 2) }
        else { hue = 60 * ((red - green) / delta + 4) }
        return PhotoColorProfile(hue: hue, saturation: maximum == 0 ? 0 : delta / maximum, luminance: 0.2126 * red + 0.7152 * green + 0.0722 * blue)
    }
}

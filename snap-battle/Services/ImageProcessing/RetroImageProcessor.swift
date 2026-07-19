import CoreGraphics
import UIKit

protocol RetroImageProcessing {
    nonisolated func process(_ image: UIImage) async throws -> UIImage
    nonisolated func recolor(_ image: UIImage, palette: [RetroColor]) async throws -> UIImage
}

struct RetroColor: Sendable, Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    nonisolated fileprivate var luminance: Double {
        0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }
}

struct RetroImageConfiguration: Sendable {
    let targetWidth: Int
    let palette: [RetroColor]

    nonisolated static let snapBattle = Self(
        targetWidth: 160,
        palette: [
            RetroColor(red: 20, green: 24, blue: 20),
            RetroColor(red: 74, green: 82, blue: 66),
            RetroColor(red: 154, green: 166, blue: 126),
            RetroColor(red: 226, green: 234, blue: 194)
        ]
    )
}

enum RetroImageProcessorError: Error {
    case invalidImage
    case contextCreationFailed
}

/// Creates the low-resolution, four-tone presentation image after all analysis is complete.
final class RetroImageProcessor: RetroImageProcessing {
    private let configuration: RetroImageConfiguration

    nonisolated init(configuration: RetroImageConfiguration = .snapBattle) {
        self.configuration = configuration
    }

    nonisolated func process(_ image: UIImage) async throws -> UIImage {
        let configuration = self.configuration
        return try await Task.detached(priority: .userInitiated) {
            try Self.processSynchronously(image, configuration: configuration)
        }.value
    }

    nonisolated func recolor(_ image: UIImage, palette: [RetroColor]) async throws -> UIImage {
        return try await Task.detached(priority: .userInitiated) {
            try Self.recolorSynchronously(image, palette: palette)
        }.value
    }

    private nonisolated static func processSynchronously(
        _ image: UIImage,
        configuration: RetroImageConfiguration
    ) throws -> UIImage {
        guard configuration.targetWidth > 0, configuration.palette.count == 4,
              let source = image.cgImage else {
            throw RetroImageProcessorError.invalidImage
        }

        let aspectRatio = CGFloat(source.height) / CGFloat(source.width)
        let width = configuration.targetWidth
        let height = max(1, Int((CGFloat(width) * aspectRatio).rounded()))
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height

        var sourcePixels = [UInt8](repeating: 0, count: byteCount)
        guard let sourceContext = CGContext(
            data: &sourcePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RetroImageProcessorError.contextCreationFailed
        }
        sourceContext.interpolationQuality = .none
        sourceContext.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminances = [Double](repeating: 0, count: width * height)
        var alphas = [UInt8](repeating: 0, count: width * height)
        for index in luminances.indices {
            let pixelIndex = index * 4
            let alpha = sourcePixels[pixelIndex + 3]
            alphas[index] = alpha
            guard alpha > 0 else { continue }
            let opacity = Double(alpha) / 255
            let red = Double(sourcePixels[pixelIndex]) / opacity
            let green = Double(sourcePixels[pixelIndex + 1]) / opacity
            let blue = Double(sourcePixels[pixelIndex + 2]) / opacity
            luminances[index] = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }

        var outputPixels = [UInt8](repeating: 0, count: byteCount)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let index = y * width + x
                let alpha = alphas[index]
                guard alpha > 0 else { continue }

                let oldLuminance = luminances[index]
                let color = configuration.palette.min { abs($0.luminance - oldLuminance) < abs($1.luminance - oldLuminance) }!
                let outputIndex = index * 4
                let opacity = Double(alpha) / 255
                outputPixels[outputIndex] = UInt8((Double(color.red) * opacity).rounded())
                outputPixels[outputIndex + 1] = UInt8((Double(color.green) * opacity).rounded())
                outputPixels[outputIndex + 2] = UInt8((Double(color.blue) * opacity).rounded())
                outputPixels[outputIndex + 3] = alpha

                let error = oldLuminance - color.luminance
                distribute(error, toX: x + 1, y: y, weight: 7.0 / 16.0, width: width, height: height, alphas: alphas, luminances: &luminances)
                distribute(error, toX: x - 1, y: y + 1, weight: 3.0 / 16.0, width: width, height: height, alphas: alphas, luminances: &luminances)
                distribute(error, toX: x, y: y + 1, weight: 5.0 / 16.0, width: width, height: height, alphas: alphas, luminances: &luminances)
                distribute(error, toX: x + 1, y: y + 1, weight: 1.0 / 16.0, width: width, height: height, alphas: alphas, luminances: &luminances)
            }
        }

        guard let outputContext = CGContext(
            data: &outputPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outputImage = outputContext.makeImage() else {
            throw RetroImageProcessorError.contextCreationFailed
        }
        return UIImage(cgImage: outputImage, scale: 1, orientation: .up)
    }

    private nonisolated static func recolorSynchronously(
        _ image: UIImage,
        palette: [RetroColor]
    ) throws -> UIImage {
        guard palette.count == 4, let source = image.cgImage else {
            throw RetroImageProcessorError.invalidImage
        }

        let width = source.width
        let height = source.height
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height

        var sourcePixels = [UInt8](repeating: 0, count: byteCount)
        guard let sourceContext = CGContext(
            data: &sourcePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RetroImageProcessorError.contextCreationFailed
        }
        sourceContext.interpolationQuality = .none
        sourceContext.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var outputPixels = [UInt8](repeating: 0, count: byteCount)
        for index in 0 ..< width * height {
            let pixelIndex = index * 4
            let alpha = sourcePixels[pixelIndex + 3]
            guard alpha > 0 else { continue }

            let opacity = Double(alpha) / 255
            let red = unpremultipliedComponent(sourcePixels[pixelIndex], opacity: opacity)
            let green = unpremultipliedComponent(sourcePixels[pixelIndex + 1], opacity: opacity)
            let blue = unpremultipliedComponent(sourcePixels[pixelIndex + 2], opacity: opacity)
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let mappedColor = palette.min { abs($0.luminance - luminance) < abs($1.luminance - luminance) }!

            outputPixels[pixelIndex] = UInt8((Double(mappedColor.red) * opacity).rounded())
            outputPixels[pixelIndex + 1] = UInt8((Double(mappedColor.green) * opacity).rounded())
            outputPixels[pixelIndex + 2] = UInt8((Double(mappedColor.blue) * opacity).rounded())
            outputPixels[pixelIndex + 3] = alpha
        }

        guard let outputContext = CGContext(
            data: &outputPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outputImage = outputContext.makeImage() else {
            throw RetroImageProcessorError.contextCreationFailed
        }
        return UIImage(cgImage: outputImage, scale: 1, orientation: .up)
    }

    private nonisolated static func unpremultipliedComponent(_ component: UInt8, opacity: Double) -> Double {
        min(255, Double(component) / opacity)
    }

    private nonisolated static func distribute(
        _ error: Double,
        toX x: Int,
        y: Int,
        weight: Double,
        width: Int,
        height: Int,
        alphas: [UInt8],
        luminances: inout [Double]
    ) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let index = y * width + x
        guard alphas[index] > 0 else { return }
        luminances[index] += error * weight
    }
}

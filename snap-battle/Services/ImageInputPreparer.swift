import CoreGraphics
import CryptoKit
import Foundation
import UIKit

enum ImagePixelBufferError: Error, Equatable {
    case invalidDimensions
    case invalidStride
    case invalidDataSize
    case unsupportedFormat
    case materializationFailed
}

enum ImagePixelFormat: Sendable, Equatable {
    case rgba8SRGBPremultipliedLast
}

enum ImagePixelOrientation: Sendable, Equatable {
    case up
}

/// An owned, immutable snapshot of normalized image pixels.
struct ImagePixelBuffer: Sendable, Equatable {
    let data: Data
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let format: ImagePixelFormat
    let orientation: ImagePixelOrientation

    init(
        data: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        format: ImagePixelFormat = .rgba8SRGBPremultipliedLast,
        orientation: ImagePixelOrientation = .up
    ) throws {
        guard width > 0, height > 0 else { throw ImagePixelBufferError.invalidDimensions }
        guard bytesPerRow == width * 4 else { throw ImagePixelBufferError.invalidStride }
        guard data.count == bytesPerRow * height else { throw ImagePixelBufferError.invalidDataSize }
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.format = format
        self.orientation = orientation
    }
}

struct PreparedImageValue: Sendable, Equatable {
    let pixels: ImagePixelBuffer
    let originalSize: PixelSize
    let processedSize: PixelSize
    let fingerprint: String
}

/// UIKit-only compatibility wrapper. It never crosses the image-preparation await.
struct PreparedImage {
    let image: UIImage
    let originalSize: PixelSize
    let processedSize: PixelSize
    let fingerprint: String
}

struct ImageInputPreparer: Sendable {
    private let fingerprintSide = 32

    /// Legacy MainActor-only path used by the pre-pivot Creature pipeline.
    func prepare(_ image: UIImage, diagnosticsRunID: String? = nil) throws -> PreparedImage {
        let runID = diagnosticsRunID ?? PerformanceDiagnostics.makeRunID()
        let source = try sourceImage(from: image)
        let originalSize = PixelSize(width: source.width, height: source.height)
        let normalized = try normalizedImage(image)
        let pixels = try makePixelBufferSnapshot(from: normalized)
        guard let normalizedCGImage = normalized.cgImage else { throw AppError.imageDecodeFailed }
        let fingerprint = try fingerprint(of: normalizedCGImage, runID: runID)
        return PreparedImage(image: normalized, originalSize: originalSize,
                             processedSize: PixelSize(width: pixels.width, height: pixels.height),
                             fingerprint: fingerprint)
    }

    /// UIKit adapter: resolves orientation and copies the exact normalized pixels into owned Data.
    func makePixelBuffer(from image: UIImage) throws -> (buffer: ImagePixelBuffer, originalSize: PixelSize) {
        let source = try sourceImage(from: image)
        let normalized = try normalizedImage(image)
        return (try makePixelBufferSnapshot(from: normalized), PixelSize(width: source.width, height: source.height))
    }

    func materialize(_ prepared: PreparedImageValue) throws -> UIImage {
        let buffer = prepared.pixels
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: buffer.data as CFData),
              let cgImage = CGImage(width: buffer.width, height: buffer.height,
                                    bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: buffer.bytesPerRow, space: colorSpace,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true,
                                    intent: .defaultIntent) else {
            throw ImagePixelBufferError.materializationFailed
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private func sourceImage(from image: UIImage) throws -> CGImage {
        guard let source = image.cgImage else { throw AppError.imageDecodeFailed }
        return source
    }

    private func normalizedImage(_ image: UIImage) throws -> UIImage {
        let source = try sourceImage(from: image)
        guard image.imageOrientation != .up else { return UIImage(cgImage: source, scale: 1, orientation: .up) }
        let swapsAxes: Bool
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored: swapsAxes = true
        default: swapsAxes = false
        }
        let size = CGSize(width: swapsAxes ? source.height : source.width,
                          height: swapsAxes ? source.width : source.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func makePixelBufferSnapshot(from image: UIImage) throws -> ImagePixelBuffer {
        guard let source = image.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw AppError.imageDecodeFailed }
        let width = source.width
        let height = source.height
        var data = Data(count: width * height * 4)
        let created = data.withUnsafeMutableBytes { bytes in
            CGContext(data: bytes.baseAddress, width: width, height: height,
                      bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }
        guard let context = created else { throw AppError.imageDecodeFailed }
        context.setBlendMode(.copy)
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return try ImagePixelBuffer(data: data, width: width, height: height, bytesPerRow: width * 4)
    }

    private func fingerprint(of image: CGImage, runID: String) throws -> String {
        let bytesPerRow = fingerprintSide * 4
        var pixels = [UInt8](repeating: 0, count: fingerprintSide * bytesPerRow)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = pixels.withUnsafeMutableBytes({ bytes in
                  CGContext(data: bytes.baseAddress, width: fingerprintSide, height: fingerprintSide,
                            bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
              }) else { throw AppError.imageDecodeFailed }
        context.interpolationQuality = .high
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: fingerprintSide, height: fingerprintSide))
        return PerformanceDiagnostics.measure("fingerprint", runID: runID, details: "side=\(fingerprintSide)") {
            SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
        }
    }
}

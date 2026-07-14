import CryptoKit
import Foundation
import UIKit

struct PreparedImage: @unchecked Sendable {
    let image: UIImage
    let originalSize: PixelSize
    let processedSize: PixelSize
    let fingerprint: String
}

struct ImageInputPreparer: Sendable {
    private let fingerprintSide = 32

    func prepare(_ image: UIImage) throws -> PreparedImage {
        guard let source = image.cgImage else { throw AppError.imageDecodeFailed }
        let originalSize = PixelSize(width: source.width, height: source.height)
        let normalized = try normalizedImage(image, source: source)
        guard let normalizedCGImage = normalized.cgImage else { throw AppError.imageDecodeFailed }
        let processedSize = PixelSize(width: normalizedCGImage.width, height: normalizedCGImage.height)
        return PreparedImage(
            image: normalized,
            originalSize: originalSize,
            processedSize: processedSize,
            fingerprint: try fingerprint(of: normalizedCGImage)
        )
    }

    private func normalizedImage(_ image: UIImage, source: CGImage) throws -> UIImage {
        guard image.imageOrientation != .up else { return UIImage(cgImage: source, scale: 1, orientation: .up) }
        let swapsAxes: Bool
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored: swapsAxes = true
        default: swapsAxes = false
        }
        let size = CGSize(
            width: swapsAxes ? source.height : source.width,
            height: swapsAxes ? source.width : source.height
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func fingerprint(of image: CGImage) throws -> String {
        let bytesPerPixel = 4
        let bytesPerRow = fingerprintSide * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: fingerprintSide * bytesPerRow)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw AppError.imageDecodeFailed }
        let created = pixels.withUnsafeMutableBytes { bytes in
            CGContext(
                data: bytes.baseAddress,
                width: fingerprintSide,
                height: fingerprintSide,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        guard let context = created else { throw AppError.imageDecodeFailed }
        context.interpolationQuality = .high
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: fingerprintSide, height: fingerprintSide))
        return SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
    }
}

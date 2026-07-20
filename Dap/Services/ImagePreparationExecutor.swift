import CoreGraphics
import CryptoKit
import Foundation

actor ImagePreparationExecutor {
    func prepare(_ input: (buffer: ImagePixelBuffer, originalSize: PixelSize), runID: String) throws -> PreparedImageValue {
        try Task.checkCancellation()
        let fingerprint = try Self.fingerprint(of: input.buffer, runID: runID)
        try Task.checkCancellation()
        let processedSize = PixelSize(width: input.buffer.width, height: input.buffer.height)
        PerformanceDiagnostics.event("imagePreparation", runID: runID,
                                     details: "originalWidth=\(input.originalSize.width) originalHeight=\(input.originalSize.height) processedWidth=\(processedSize.width) processedHeight=\(processedSize.height) executor=imagePreparation")
        return PreparedImageValue(pixels: input.buffer, originalSize: input.originalSize,
                                  processedSize: processedSize, fingerprint: fingerprint)
    }

    private static func fingerprint(of pixels: ImagePixelBuffer, runID: String) throws -> String {
        let side = 32
        let bytesPerRow = side * 4
        var output = [UInt8](repeating: 0, count: side * bytesPerRow)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: pixels.data as CFData),
              let image = CGImage(width: pixels.width, height: pixels.height,
                                  bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: pixels.bytesPerRow, space: colorSpace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true,
                                  intent: .defaultIntent),
              let context = output.withUnsafeMutableBytes({ bytes in
                  CGContext(data: bytes.baseAddress, width: side, height: side,
                            bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
              }) else { throw AppError.imageDecodeFailed }
        context.interpolationQuality = .high
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return PerformanceDiagnostics.measure("fingerprint", runID: runID, details: "side=\(side)") {
            SHA256.hash(data: Data(output)).map { String(format: "%02x", $0) }.joined()
        }
    }
}

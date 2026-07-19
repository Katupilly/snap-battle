import Foundation
import Testing
import UIKit
@testable import snap_battle

struct PitchColorRetroProcessorTests {
    @Test func sameInputAndPitchClassProduceSameRecoloredCover() async throws {
        let source = sampleSourceImage()
        let processor = RetroImageProcessor()
        let baseCover = try await processor.process(source)
        let palette = retroPalette(for: .cSharp)

        let first = try await processor.recolor(baseCover, palette: palette)
        let second = try await processor.recolor(baseCover, palette: palette)

        #expect(first.pngData() == second.pngData())
    }

    @Test func differentPitchClassesProduceDifferentPalettes() async throws {
        let source = sampleSourceImage()
        let processor = RetroImageProcessor()
        let baseCover = try await processor.process(source)

        let first = try await processor.recolor(baseCover, palette: retroPalette(for: .c))
        let second = try await processor.recolor(baseCover, palette: retroPalette(for: .fSharp))

        #expect(first.pngData() != second.pngData())
    }

    @Test func recoloringPreservesDimensionsAlphaAndOrientation() async throws {
        let transparent = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24)).image { context in
            UIColor.clear.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 4, y: 4, width: 12, height: 8))
        }
        let oriented = UIImage(cgImage: try #require(transparent.cgImage), scale: 1, orientation: .left)
        let processor = RetroImageProcessor()
        let baseCover = try await processor.process(oriented)
        let recolored = try await processor.recolor(baseCover, palette: retroPalette(for: .aSharp))

        #expect(recolored.cgImage?.width == baseCover.cgImage?.width)
        #expect(recolored.cgImage?.height == baseCover.cgImage?.height)
        #expect(recolored.imageOrientation == .up)
        #expect(try pixels(in: recolored).contains { $0.3 == 0 })
    }

    @Test func recoloringHandlesPremultipliedTransparentPixels() async throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor(white: 1, alpha: 0.25).setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let processor = RetroImageProcessor()
        let recolored = try await processor.recolor(source, palette: retroPalette(for: .e))
        let pixel = try #require(pixels(in: recolored).first)

        #expect(pixel.3 > 0)
        #expect(pixel.0 <= pixel.3)
        #expect(pixel.1 <= pixel.3)
        #expect(pixel.2 <= pixel.3)
    }

    @Test func recolorRespectsCancellation() async throws {
        let source = sampleSourceImage()
        let processor = RetroImageProcessor()
        let baseCover = try await processor.process(source)
        let task = Task {
            try await processor.recolor(baseCover, palette: retroPalette(for: .gSharp))
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    private func sampleSourceImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 24)).image { context in
            for row in 0 ..< 6 {
                for column in 0 ..< 10 {
                    UIColor(
                        hue: CGFloat((row * 73 + column * 29) % 360) / 360,
                        saturation: 0.78,
                        brightness: 0.85,
                        alpha: column.isMultiple(of: 5) ? 0.65 : 1
                    ).setFill()
                    context.cgContext.fill(CGRect(x: column * 4, y: row * 4, width: 4, height: 4))
                }
            }
        }
    }

    private func retroPalette(for pitchClass: PitchClass) -> [RetroColor] {
        let palette = PitchColorIdentity.tonalPalette(for: pitchClass)
        return palette.colors.map { RetroColor(red: $0.red, green: $0.green, blue: $0.blue) }
    }

    private func pixels(in image: UIImage) throws -> [(UInt8, UInt8, UInt8, UInt8)] {
        guard let cgImage = image.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw AppError.imageDecodeFailed
        }
        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AppError.imageDecodeFailed
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: buffer.count, by: 4).map { index in
            (buffer[index], buffer[index + 1], buffer[index + 2], buffer[index + 3])
        }
    }
}

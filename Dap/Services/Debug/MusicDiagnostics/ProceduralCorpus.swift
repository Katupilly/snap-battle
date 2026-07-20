#if DEBUG
import CommonCrypto
import CoreGraphics
import Foundation
import UIKit

/// A reproducible, in-process corpus used to baseline the v1 photo-to-MIDI
/// algorithm.
///
/// Every fixture is a small (64×64) `UIImage` produced by
/// `UIGraphicsImageRenderer` from a closed-set of color regions. There is
/// no RNG and no I/O: the same `(category, index)` pair always produces
/// the same pixel data.
///
/// The fixture size matches `PedalHeuristics.analysisSide` so the
/// analyzer sees the exact pixels without downsampling.
enum ProceduralCorpus {

    /// One fixture in the corpus.
    struct Fixture: Equatable, Sendable, Identifiable {
        let identifier: String   // e.g. `portraitDay-000`
        let category: CorpusCategory
        let image: UIImage
        let pixelHash: String    // SHA-256 of the RGBA pixel buffer (for stability tests)

        var id: String { identifier }
    }

    /// All fixtures for the procedural corpus, one per `CorpusCategory`.
    /// The order is `CorpusCategory.allCases` order, with a single fixture
    /// per category.
    static func fixtures() -> [Fixture] {
        CorpusCategory.allCases.map { category in
            makeFixture(category: category, index: 0)
        }
    }

    /// Build a single fixture for a given category and index.
    /// Multiple indices per category would let the corpus grow without
    /// changing the analyzer expectations; the current harness uses
    /// `index == 0` only.
    static func makeFixture(category: CorpusCategory, index: Int) -> Fixture {
        let image = render(category: category)
        let pixelHash = stableHash(for: image)
        let identifier = "\(category.identifierPrefix)-\(String(format: "%03d", index))"
        return Fixture(
            identifier: identifier,
            category: category,
            image: image,
            pixelHash: pixelHash
        )
    }

    // MARK: - Rendering

    private static let size = CGSize(width: 64, height: 64)

    private static func render(category: CorpusCategory) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            draw(category: category, in: cg, size: size)
        }
    }

    private static func draw(category: CorpusCategory, in cg: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        let palette = palette(for: category)

        // Base fill
        palette.background.setFill()
        cg.fill(rect)

        switch category {
        case .portraitDay, .portraitNight:
            // Single warm block, slight gradient, soft edges.
            palette.primary.setFill()
            cg.fill(rect.insetBy(dx: 4, dy: 8))
            // Soft highlight on top half.
            palette.highlight.withAlphaComponent(0.35).setFill()
            cg.fill(CGRect(x: 4, y: 8, width: size.width - 8, height: 14))

        case .landscapeDay:
            // Sky (top) + ground (bottom).
            palette.background.setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height / 2))
            palette.primary.setFill()
            cg.fill(CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2))

        case .landscapeNight:
            // Dark blue with subtle horizon.
            palette.background.setFill()
            cg.fill(rect)
            palette.primary.withAlphaComponent(0.6).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.55, width: size.width, height: size.height * 0.45))

        case .object:
            // Background then a centered object.
            palette.background.setFill()
            cg.fill(rect)
            palette.primary.setFill()
            cg.fill(CGRect(x: 18, y: 18, width: 28, height: 28))

        case .architecture:
            // Yellow background with diagonal lines for high edge density.
            palette.background.setFill()
            cg.fill(rect)
            palette.primary.setFill()
            for i in stride(from: -Int(size.height), to: Int(size.width) + Int(size.height), by: 6) {
                cg.move(to: CGPoint(x: i, y: 0))
                cg.addLine(to: CGPoint(x: i + Int(size.height), y: Int(size.height)))
                cg.setLineWidth(2)
                cg.strokePath()
            }

        case .nature:
            // Green field + some blue patches.
            palette.background.setFill()
            cg.fill(rect)
            palette.primary.setFill()
            for row in 0..<3 {
                for col in 0..<4 {
                    cg.fill(CGRect(x: col * 16 + (row.isMultiple(of: 2) ? 4 : 0),
                                   y: row * 18 + 6,
                                   width: 12, height: 12))
                }
            }
            palette.secondary.withAlphaComponent(0.6).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size.width, height: 6))

        case .lowSaturation:
            // Subtle gradient, near-gray.
            let colors = [palette.background.cgColor, palette.primary.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: 0),
                                      end: CGPoint(x: size.width, y: size.height),
                                      options: [])
            }

        case .highSaturation:
            // Three large bands of vivid colors.
            let colors = [palette.primary.cgColor, palette.secondary.cgColor, palette.background.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: 0),
                                      end: CGPoint(x: size.width, y: 0),
                                      options: [])
            }

        case .bright:
            // Very light, low contrast.
            palette.background.setFill()
            cg.fill(rect)
            palette.primary.withAlphaComponent(0.25).setFill()
            cg.fill(CGRect(x: 16, y: 16, width: 32, height: 32))

        case .dark:
            // Very dark, low contrast.
            palette.background.setFill()
            cg.fill(rect)
            palette.primary.withAlphaComponent(0.25).setFill()
            cg.fill(CGRect(x: 16, y: 16, width: 32, height: 32))

        case .centralSubject:
            // Warm center on cool background.
            palette.background.setFill()
            cg.fill(rect)
            palette.primary.setFill()
            cg.fillEllipse(in: CGRect(x: 12, y: 12, width: 40, height: 40))

        case .noClearSubject:
            // Diagonal gradient with no clear boundary.
            let colors = [palette.background.cgColor, palette.primary.cgColor, palette.secondary.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: 0),
                                      end: CGPoint(x: size.width, y: size.height),
                                      options: [])
            }

        case .synthetic:
            // Solid red.
            palette.primary.setFill()
            cg.fill(rect)
        }
    }

    private struct Palette {
        let background: UIColor
        let primary: UIColor
        let secondary: UIColor
        let highlight: UIColor
    }

    private static func palette(for category: CorpusCategory) -> Palette {
        switch category {
        case .portraitDay:
            return Palette(
                background: UIColor(red: 0.78, green: 0.58, blue: 0.45, alpha: 1),
                primary: UIColor(red: 0.85, green: 0.65, blue: 0.50, alpha: 1),
                secondary: UIColor(red: 0.55, green: 0.35, blue: 0.25, alpha: 1),
                highlight: UIColor(red: 1.00, green: 0.88, blue: 0.75, alpha: 1)
            )
        case .portraitNight:
            return Palette(
                background: UIColor(red: 0.20, green: 0.13, blue: 0.10, alpha: 1),
                primary: UIColor(red: 0.30, green: 0.20, blue: 0.14, alpha: 1),
                secondary: UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1),
                highlight: UIColor(red: 0.45, green: 0.30, blue: 0.22, alpha: 1)
            )
        case .landscapeDay:
            return Palette(
                background: UIColor(red: 0.45, green: 0.70, blue: 0.85, alpha: 1), // sky blue
                primary: UIColor(red: 0.30, green: 0.60, blue: 0.20, alpha: 1),    // grass
                secondary: UIColor(red: 0.10, green: 0.40, blue: 0.15, alpha: 1),
                highlight: UIColor(red: 0.65, green: 0.85, blue: 0.95, alpha: 1)
            )
        case .landscapeNight:
            return Palette(
                background: UIColor(red: 0.05, green: 0.10, blue: 0.20, alpha: 1),
                primary: UIColor(red: 0.10, green: 0.18, blue: 0.32, alpha: 1),
                secondary: UIColor(red: 0.02, green: 0.05, blue: 0.10, alpha: 1),
                highlight: UIColor(red: 0.30, green: 0.40, blue: 0.55, alpha: 1)
            )
        case .object:
            return Palette(
                background: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
                primary: UIColor(red: 0.95, green: 0.20, blue: 0.10, alpha: 1),
                secondary: UIColor(red: 0.40, green: 0.10, blue: 0.05, alpha: 1),
                highlight: UIColor(red: 1.00, green: 0.50, blue: 0.40, alpha: 1)
            )
        case .architecture:
            return Palette(
                background: UIColor(red: 0.60, green: 0.55, blue: 0.45, alpha: 1),
                primary: UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1),
                secondary: UIColor(red: 0.85, green: 0.75, blue: 0.50, alpha: 1),
                highlight: UIColor(red: 0.95, green: 0.90, blue: 0.75, alpha: 1)
            )
        case .nature:
            return Palette(
                background: UIColor(red: 0.25, green: 0.50, blue: 0.18, alpha: 1),
                primary: UIColor(red: 0.18, green: 0.40, blue: 0.12, alpha: 1),
                secondary: UIColor(red: 0.45, green: 0.65, blue: 0.85, alpha: 1),
                highlight: UIColor(red: 0.55, green: 0.80, blue: 0.30, alpha: 1)
            )
        case .lowSaturation:
            return Palette(
                background: UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1),
                primary: UIColor(red: 0.62, green: 0.62, blue: 0.65, alpha: 1),
                secondary: UIColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1),
                highlight: UIColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1)
            )
        case .highSaturation:
            return Palette(
                background: UIColor(red: 0.10, green: 0.40, blue: 0.95, alpha: 1),
                primary: UIColor(red: 0.95, green: 0.10, blue: 0.20, alpha: 1),
                secondary: UIColor(red: 0.10, green: 0.85, blue: 0.20, alpha: 1),
                highlight: UIColor(red: 1.00, green: 0.95, blue: 0.10, alpha: 1)
            )
        case .bright:
            return Palette(
                background: UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
                primary: UIColor(red: 0.80, green: 0.80, blue: 0.82, alpha: 1),
                secondary: UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1),
                highlight: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1)
            )
        case .dark:
            return Palette(
                background: UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1),
                primary: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1),
                secondary: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1),
                highlight: UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1)
            )
        case .centralSubject:
            return Palette(
                background: UIColor(red: 0.10, green: 0.40, blue: 0.70, alpha: 1),
                primary: UIColor(red: 0.95, green: 0.55, blue: 0.35, alpha: 1),
                secondary: UIColor(red: 0.55, green: 0.20, blue: 0.15, alpha: 1),
                highlight: UIColor(red: 1.00, green: 0.80, blue: 0.65, alpha: 1)
            )
        case .noClearSubject:
            return Palette(
                background: UIColor(red: 0.40, green: 0.30, blue: 0.50, alpha: 1),
                primary: UIColor(red: 0.30, green: 0.45, blue: 0.55, alpha: 1),
                secondary: UIColor(red: 0.20, green: 0.60, blue: 0.55, alpha: 1),
                highlight: UIColor(red: 0.55, green: 0.35, blue: 0.65, alpha: 1)
            )
        case .synthetic:
            return Palette(
                background: UIColor(red: 0.80, green: 0.10, blue: 0.10, alpha: 1),
                primary: UIColor(red: 0.80, green: 0.10, blue: 0.10, alpha: 1),
                secondary: UIColor(red: 0.80, green: 0.10, blue: 0.10, alpha: 1),
                highlight: UIColor(red: 0.80, green: 0.10, blue: 0.10, alpha: 1)
            )
        }
    }

    // MARK: - Stability hash

    /// Hash the raw RGBA bytes of a `UIImage` so callers can verify the
    /// same image is produced by repeat invocations.
    static func stableHash(for image: UIImage) -> String {
        guard let cgImage = image.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return "no-cgimage"
        }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = pixels.withUnsafeMutableBytes({ raw in
            CGContext(data: raw.baseAddress,
                      width: width, height: height,
                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }) else {
            return "no-context"
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Self.sha256Hex(of: pixels)
    }

    private static func sha256Hex(of bytes: [UInt8]) -> String {
        var hasher = SHA256Hasher()
        hasher.update(bytes: bytes)
        return hasher.finalizeHex()
    }
}

// MARK: - Local SHA-256 helper

/// Minimal `SHA256` wrapper used to hash the raw RGBA bytes of a
/// `UIImage`. Uses `CommonCrypto` for the actual digest so this file
/// does not pull in `CryptoKit` for a single 32-byte hash.
private struct SHA256Hasher {
    private var context = CC_SHA256_CTX()

    init() {
        CC_SHA256_Init(&context)
    }

    mutating func update(bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer { buffer in
            _ = CC_SHA256_Update(&context, buffer.baseAddress, CC_LONG(buffer.count))
        }
    }

    mutating func finalizeHex() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
#endif

import Foundation
import Testing
import UIKit
@testable import snap_battle

struct ThumbnailLoaderTests {
    @Test func downsampleUsesRequestedPixelScaleAndBoundsTheLargestDimension() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let assetURL = directory.appendingPathComponent("cover.png")
        try sourceImage(size: CGSize(width: 1_000, height: 500)).pngData()!.write(to: assetURL)

        let loader = ThumbnailLoader()
        let image = try await loader.loadThumbnail(
            for: PersistedImageAsset(identity: "pedal-1", fileURL: assetURL),
            targetSize: CGSize(width: 100, height: 100),
            pixelScale: 2
        )

        #expect(image.cgImage?.width == 200)
        #expect(image.cgImage?.height == 100)
    }

    @Test func cacheUsesStableIdentityAndExactSizeAndScaleKey() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let assetURL = directory.appendingPathComponent("cover.png")
        try sourceImage(size: CGSize(width: 400, height: 400)).pngData()!.write(to: assetURL)

        let loader = ThumbnailLoader()
        let asset = PersistedImageAsset(identity: "pedal-1", fileURL: assetURL)
        _ = try await loader.loadThumbnail(
            for: asset,
            targetSize: CGSize(width: 80, height: 80),
            pixelScale: 2
        )
        try FileManager.default.removeItem(at: assetURL)

        let cached = try await loader.loadThumbnail(
            for: asset,
            targetSize: CGSize(width: 80, height: 80),
            pixelScale: 2
        )
        #expect(cached.cgImage?.width == 160)

        await #expect(throws: ThumbnailLoaderError.assetUnavailable) {
            try await loader.loadThumbnail(
                for: asset,
                targetSize: CGSize(width: 80, height: 80),
                pixelScale: 3
            )
        }
    }

    @Test func invalidAssetReturnsPlaceholderWithoutCrashing() async throws {
        let placeholder = sourceImage(size: CGSize(width: 4, height: 4))
        let asset = PersistedImageAsset(
            identity: "pedal-missing",
            fileURL: URL(fileURLWithPath: "/missing/cover.png")
        )

        let result = await ThumbnailLoader().loadThumbnailOrPlaceholder(
            for: asset,
            targetSize: CGSize(width: 40, height: 40),
            pixelScale: 2,
            placeholder: placeholder
        )

        #expect(result === placeholder)
    }

    @Test func cancelledLoadDoesNotReturnAnImage() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let assetURL = directory.appendingPathComponent("cover.png")
        try sourceImage(size: CGSize(width: 100, height: 100)).pngData()!.write(to: assetURL)
        let loader = ThumbnailLoader()
        let task = Task {
            try await loader.loadThumbnail(
                for: PersistedImageAsset(identity: "pedal-cancel", fileURL: assetURL),
                targetSize: CGSize(width: 40, height: 40),
                pixelScale: 2
            )
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbnailLoaderTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func sourceImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

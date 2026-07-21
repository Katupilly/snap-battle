import Foundation
import ImageIO
import UIKit

/// A persisted image and the stable identity that owns it.
///
/// The identity should be the persisted record ID (for example, a pedal UUID),
/// not a grid position or a property of the image bytes.
public struct PersistedImageAsset: Hashable, Sendable {
    public let identity: String
    public let fileURL: URL

    nonisolated public init(identity: String, fileURL: URL) {
        self.identity = identity
        self.fileURL = fileURL
    }
}

public enum ThumbnailLoaderError: Error, Equatable {
    case invalidAssetIdentity
    case invalidTargetSize
    case invalidPixelScale
    case assetUnavailable
    case invalidImage
}

/// Loads persisted images as bounded, cacheable thumbnails.
///
/// This type only reads the supplied file URL. It does not write thumbnails to
/// disk and does not own persistence. Cache entries are keyed by the supplied
/// stable identity and the exact requested point size/scale.
public final class ThumbnailLoader: @unchecked Sendable {
    nonisolated public static let defaultCacheCountLimit = 64
    nonisolated public static let defaultCacheTotalCostLimit = 32 * 1024 * 1024
    nonisolated public static let maximumPixelDimension = 4_096

    // NSCache is documented as thread-safe; the loader is @unchecked Sendable
    // so this reference can be used by its nonisolated API.
    nonisolated(unsafe) private let cache: NSCache<NSString, UIImage>

    nonisolated public init(
        cacheCountLimit: Int = ThumbnailLoader.defaultCacheCountLimit,
        cacheTotalCostLimit: Int = ThumbnailLoader.defaultCacheTotalCostLimit
    ) {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = max(0, cacheCountLimit)
        cache.totalCostLimit = max(0, cacheTotalCostLimit)
        self.cache = cache
    }

    /// Loads and downsamples a persisted image. Cancellation is propagated as
    /// `CancellationError`; malformed or unavailable assets return a typed
    /// error instead of crashing.
    nonisolated public func loadThumbnail(
        for asset: PersistedImageAsset,
        targetSize: CGSize,
        pixelScale: CGFloat
    ) async throws -> UIImage {
        let request = try ThumbnailRequest(
            asset: asset,
            targetSize: targetSize,
            pixelScale: pixelScale
        )

        try Task.checkCancellation()
        if let cached = cache.object(forKey: request.cacheKey as NSString) {
            return cached
        }

        let decodeTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let data: Data
            do {
                data = try Data(contentsOf: request.asset.fileURL, options: [.mappedIfSafe])
            } catch {
                throw ThumbnailLoaderError.assetUnavailable
            }

            let image = try Self.downsample(
                data: data,
                maximumPixelDimension: request.maximumPixelDimension
            )
            try Task.checkCancellation()
            return image
        }

        let image: UIImage
        do {
            image = try await withTaskCancellationHandler(operation: {
                try await decodeTask.value
            }, onCancel: {
                decodeTask.cancel()
            })
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ThumbnailLoaderError {
            throw error
        } catch {
            throw ThumbnailLoaderError.invalidImage
        }

        try Task.checkCancellation()
        cache.setObject(image, forKey: request.cacheKey as NSString, cost: Self.cacheCost(of: image))
        return image
    }

    /// Safe presentation-oriented API. It returns the supplied placeholder (or
    /// nil when no placeholder is supplied) for cancellation and load failures.
    nonisolated public func loadThumbnailOrPlaceholder(
        for asset: PersistedImageAsset,
        targetSize: CGSize,
        pixelScale: CGFloat,
        placeholder: UIImage? = nil
    ) async -> UIImage? {
        do {
            return try await loadThumbnail(
                for: asset,
                targetSize: targetSize,
                pixelScale: pixelScale
            )
        } catch {
            return placeholder
        }
    }

    /// Removes all cached thumbnails without affecting persisted assets.
    nonisolated public func removeAllCachedThumbnails() {
        cache.removeAllObjects()
    }

}

private struct ThumbnailRequest: Sendable {
    let asset: PersistedImageAsset
    let cacheKey: String
    let maximumPixelDimension: Int

    nonisolated init(asset: PersistedImageAsset, targetSize: CGSize, pixelScale: CGFloat) throws {
        guard !asset.identity.isEmpty else {
            throw ThumbnailLoaderError.invalidAssetIdentity
        }
        guard targetSize.width.isFinite, targetSize.height.isFinite,
              targetSize.width > 0, targetSize.height > 0 else {
            throw ThumbnailLoaderError.invalidTargetSize
        }
        guard pixelScale.isFinite, pixelScale > 0 else {
            throw ThumbnailLoaderError.invalidPixelScale
        }

        let maximumRequestedDimension = max(targetSize.width, targetSize.height) * pixelScale
        guard maximumRequestedDimension.isFinite,
              maximumRequestedDimension <= CGFloat(Int.max) else {
            throw ThumbnailLoaderError.invalidTargetSize
        }

        let maximumPixelDimension = min(
            ThumbnailLoader.maximumPixelDimension,
            max(1, Int(ceil(maximumRequestedDimension)))
        )
        self.asset = asset
        self.maximumPixelDimension = maximumPixelDimension
        self.cacheKey = Self.makeCacheKey(
            identity: asset.identity,
            targetSize: targetSize,
            pixelScale: pixelScale
        )
    }

    nonisolated private static func makeCacheKey(
        identity: String,
        targetSize: CGSize,
        pixelScale: CGFloat
    ) -> String {
        let encodedIdentity = Data(identity.utf8).base64EncodedString()
        let widthBits = Double(targetSize.width).bitPattern
        let heightBits = Double(targetSize.height).bitPattern
        let scaleBits = Double(pixelScale).bitPattern
        return "\(encodedIdentity)|w\(widthBits)|h\(heightBits)|s\(scaleBits)"
    }
}

private extension ThumbnailLoader {
    nonisolated static func downsample(data: Data, maximumPixelDimension: Int) throws -> UIImage {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            sourceOptions as CFDictionary
        ) else {
            throw ThumbnailLoaderError.invalidImage
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw ThumbnailLoaderError.invalidImage
        }
        return UIImage(cgImage: image)
    }

    nonisolated static func cacheCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        let rowCost = max(cgImage.bytesPerRow, cgImage.width * 4)
        let (cost, overflow) = rowCost.multipliedReportingOverflow(by: cgImage.height)
        return overflow ? Int.max : max(1, cost)
    }
}

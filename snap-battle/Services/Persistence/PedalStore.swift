import Foundation
import UIKit

enum PedalStore {
    private static let fileName = "latest-pedal.json"
    private static let coverName = "latest-pedal.png"
    private static var directory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }
    private static var jsonURL: URL { directory.appendingPathComponent(fileName) }
    private static var coverURL: URL { directory.appendingPathComponent(coverName) }

    static func save(_ pedal: PhotoPedal, cover: UIImage) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let png = cover.pngData() else { throw AppError.imageDecodeFailed }
        try png.write(to: coverURL, options: .atomic)
        try JSONEncoder().encode(pedal).write(to: jsonURL, options: .atomic)
    }

    static func loadLatest() -> (pedal: PhotoPedal, cover: UIImage)? {
        guard let pedal = try? JSONDecoder().decode(PhotoPedal.self, from: Data(contentsOf: jsonURL)), let cover = UIImage(contentsOfFile: coverURL.path) else { return nil }
        return (pedal, cover)
    }
}

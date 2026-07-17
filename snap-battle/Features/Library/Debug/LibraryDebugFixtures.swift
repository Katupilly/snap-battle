#if DEBUG
import Foundation
import UIKit

enum LibraryDebugDataset: String, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large

    var id: Self { self }

    var count: Int {
        switch self {
        case .small: 50
        case .medium: 200
        case .large: 500
        }
    }

    var title: String { "\(count) pedais" }
}

struct LibraryDebugFixtureStore {
    let rootDirectory: URL
    private let makeStore: (URL) -> PedalStore

    init(fileManager: FileManager = .default, makeStore: @escaping (URL) -> PedalStore = { PedalStore(directory: $0) }) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootDirectory = support.appendingPathComponent("debug-library-fixtures", isDirectory: true)
        self.makeStore = makeStore
    }

    init(rootDirectory: URL, makeStore: @escaping (URL) -> PedalStore = { PedalStore(directory: $0) }) {
        self.rootDirectory = rootDirectory.appendingPathComponent("debug-library-fixtures", isDirectory: true)
        self.makeStore = makeStore
    }

    func store(for dataset: LibraryDebugDataset) -> PedalStore {
        makeStore(rootDirectory.appendingPathComponent(dataset.rawValue, isDirectory: true))
    }

    func reset(dataset: LibraryDebugDataset) {
        try? FileManager.default.removeItem(at: rootDirectory.appendingPathComponent(dataset.rawValue, isDirectory: true))
    }

    @discardableResult
    func install(_ dataset: LibraryDebugDataset) throws -> PedalStore {
        reset(dataset: dataset)
        let store = store(for: dataset)
        for index in 0..<dataset.count {
            let pedal = Self.pedal(index: index, dataset: dataset)
            try store.save(pedal, cover: Self.cover(index: index))
        }
        try installCorruptSentinel(in: store)
        return store
    }

    @MainActor
    func installAndLoad(_ dataset: LibraryDebugDataset) throws -> LibraryDebugLoadedDataset {
        let store = try install(dataset)
        let model = GalleryViewModel(store: store, player: PhotoPedalSynth())
        let loaded = model.reload()
        let unavailableIDs = Set(loaded.pedals.enumerated().compactMap { $0.offset % 23 == 0 ? $0.element.id : nil })
        return LibraryDebugLoadedDataset(model: model, loadResult: loaded, unavailableIDs: unavailableIDs)
    }

    static func stableID(index: Int) -> UUID {
        UUID(uuidString: "D06B0000-0000-4000-8000-\(String(format: "%012X", index + 1))")!
    }

    static func pedal(index: Int, dataset: LibraryDebugDataset) -> PhotoPedal {
        let date = date(for: index, total: dataset.count)
        let longName = index % 9 == 0
        let name = longName
            ? "Fixture \(index + 1): \(String(repeating: "Long Name ", count: 3))"
            : ["Amber Grid", "Night Bloom", "Pixel Current", "Soft Relay", "Chrome Rain"][index % 5] + " \(index + 1)"
        let description = index % 7 == 0
            ? "Uma descrição extensa de fixture para exercitar Dynamic Type, quebra de linha, navegação e leitura sem depender de conteúdo externo. Item \(index + 1)."
            : "Capa sintética determinística para validação da Biblioteca, item \(index + 1)."
        let harmony = PedalHarmony(
            rootPitchClass: index % 12,
            scale: PedalScale.allCases[index % PedalScale.allCases.count],
            bpm: 72 + (index * 7 % 96)
        )
        let notes = (0..<PedalSequence.steps).map { step in
            PedalNote(step: step, row: (index + step) % PedalSequence.rows, midiNote: 48 + ((index + step) % 24), velocity: 0.45 + Float((index + step) % 5) * 0.1)
        }
        let profile = PedalSoundProfile(
            gate: 0.6 + Double(index % 4) * 0.1,
            octaveRange: 1 + Double(index % 3),
            waveform: index.isMultiple(of: 2) ? .square : .triangle,
            reverbPreset: [.smallRoom, .mediumRoom, .cathedral][index % 3],
            distortionPreset: [.multiEcho1, .drumsBitBrush][index % 2],
            defaultReverbMix: 48,
            defaultDistortionMix: 55,
            reverbMix: 30 + Double(index % 6) * 8,
            distortionMix: 25 + Double(index % 5) * 10
        )
        return PhotoPedal(
            id: stableID(index: index),
            name: name,
            description: description,
            sequence: PedalSequence(harmony: harmony, notes: notes, soundProfile: profile),
            effect: PedalEffect.allCases[index % PedalEffect.allCases.count],
            createdAt: date,
            coverFilename: "\(stableID(index: index).uuidString).png"
        )
    }

    static func cover(index: Int) -> UIImage {
        let size = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: size).image { context in
            let hue = CGFloat((index * 37) % 360) / 360
            UIColor(hue: hue, saturation: 0.72, brightness: 0.82, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.28).setFill()
            for row in 0..<8 where (row + index) % 2 == 0 {
                for column in 0..<8 where (column * 3 + index) % 4 < 2 {
                    context.fill(CGRect(x: column * 8, y: row * 8, width: 8, height: 8))
                }
            }
            UIColor.black.withAlphaComponent(0.55).setFill()
            context.fill(CGRect(x: 4, y: 4, width: 18, height: 10))
            let label = "\(index + 1)" as NSString
            label.draw(at: CGPoint(x: 6, y: 3), withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 7, weight: .bold), .foregroundColor: UIColor.white])
        }
    }

    private static func date(for index: Int, total: Int) -> Date {
        if index > 0, index.isMultiple(of: 17) { return date(for: 0, total: total) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 12))!
        let monthOffset = index % 18
        let day = 1 + ((index * 5) % 26)
        let second = index % 17 == 0 ? 0 : index % 60
        let date = calendar.date(byAdding: .month, value: monthOffset, to: base)!
        return calendar.date(byAdding: .day, value: day - 15, to: date)!.addingTimeInterval(TimeInterval(second + total % 3))
    }

    private func installCorruptSentinel(in store: PedalStore) throws {
        let directory = store.debugCollectionDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("corrupt debug fixture".utf8).write(to: directory.appendingPathComponent("D06B0000-0000-4000-8000-FFFFFFFFFFFF.json"))
    }
}

@MainActor
struct LibraryDebugLoadedDataset {
    let model: GalleryViewModel
    let loadResult: PedalStoreLoadResult
    let unavailableIDs: Set<UUID>
}

#endif

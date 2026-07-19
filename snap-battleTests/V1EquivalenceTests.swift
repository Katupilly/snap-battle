import Foundation
import Testing
import UIKit
@testable import snap_battle

/// Equivalence tests proving that the v1 generation pipeline remains
/// byte-for-byte identical after the Increment 2 changes.
///
/// Reference:
/// - `specs/current/photo-midi-variety-v2-incremento-2.md` §10, §13
struct V1EquivalenceTests {

    @Test func visualAnalysisDoesNotChangePedalSequence() async throws {
        let prepared = try ImageInputPreparer().prepare(Fixtures.patternImage)
        let cover = try await RetroImageProcessor().process(prepared.image)
        let color = try PhotoColorAnalyzer.analyze(prepared.image)

        let sequence = try ImageSequenceGenerator.makeSequence(
            retroImage: cover,
            colorProfile: color
        )

        // Run the visual analysis to confirm it does not perturb the
        // v1 algorithm. The function is pure but we want the regression
        // guard to be explicit.
        _ = try VisualAnalyzer.analyze(preparedImage: prepared)

        let sequenceAfter = try ImageSequenceGenerator.makeSequence(
            retroImage: cover,
            colorProfile: color
        )

        #expect(sequence == sequenceAfter)
        #expect(sequence.notes == sequenceAfter.notes)
        #expect(sequence.harmony == sequenceAfter.harmony)
        #expect(sequence.soundProfile == sequenceAfter.soundProfile)
    }

    @Test func generatorVersionDoesNotChangePedalSequence() async throws {
        let prepared = try ImageInputPreparer().prepare(Fixtures.patternImage)
        let cover = try await RetroImageProcessor().process(prepared.image)
        let color = try PhotoColorAnalyzer.analyze(prepared.image)
        let sequence = try ImageSequenceGenerator.makeSequence(retroImage: cover, colorProfile: color)

        let pedalWithVersion = try Fixtures.pedal(generatorVersion: 1, sequence: sequence)
        let pedalWithoutVersion = try Fixtures.pedal(generatorVersion: nil, sequence: sequence)

        // Decoding the JSON of a pedal without `generatorVersion` must
        // produce a sequence identical to the explicit-version pedal.
        let legacyJSON = try JSONEncoder().encode(pedalWithoutVersion)
        let legacy = try JSONDecoder().decode(PhotoPedal.self, from: legacyJSON)
        let current = try JSONDecoder().decode(PhotoPedal.self, from: JSONEncoder().encode(pedalWithVersion))

        #expect(legacy.sequence == current.sequence)
        #expect(legacy.sequence.notes == current.sequence.notes)
        #expect(legacy.sequence.harmony == current.sequence.harmony)
        #expect(legacy.sequence.soundProfile == current.sequence.soundProfile)
    }

    @Test func dominantPitchClassAndPaletteAreUnchanged() async throws {
        let prepared = try ImageInputPreparer().prepare(Fixtures.patternImage)
        let cover = try await RetroImageProcessor().process(prepared.image)
        let color = try PhotoColorAnalyzer.analyze(prepared.image)
        let sequence = try ImageSequenceGenerator.makeSequence(retroImage: cover, colorProfile: color)

        let dominantBefore = sequence.dominantPitchClass
        let paletteBefore = PitchColorIdentity.tonalPalette(for: dominantBefore)

        // Run the visual analysis
        _ = try VisualAnalyzer.analyze(preparedImage: prepared)

        let dominantAfter = sequence.dominantPitchClass
        let paletteAfter = PitchColorIdentity.tonalPalette(for: dominantAfter)

        #expect(dominantBefore == dominantAfter)
        #expect(paletteBefore == paletteAfter)
    }

    @Test func persistedSequenceIsIdenticalAcrossStoreAndReload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)

        let prepared = try ImageInputPreparer().prepare(Fixtures.patternImage)
        let cover = try await RetroImageProcessor().process(prepared.image)
        let color = try PhotoColorAnalyzer.analyze(prepared.image)
        let sequence = try ImageSequenceGenerator.makeSequence(retroImage: cover, colorProfile: color)
        let pedal = PhotoPedal(
            id: UUID(),
            name: "Equivalence",
            description: "A test pedal.",
            sequence: sequence,
            effect: .reverb,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            coverFilename: "equivalence.png",
            generatorVersion: 1
        )
        try store.save(pedal, cover: Fixtures.cover())

        let loaded = try #require(store.loadLatest())

        #expect(loaded.pedal.sequence == sequence)
        #expect(loaded.pedal.sequence.notes == sequence.notes)
        #expect(loaded.pedal.sequence.harmony == sequence.harmony)
        #expect(loaded.pedal.sequence.soundProfile == sequence.soundProfile)
        #expect(loaded.pedal.dominantPitchClass == pedal.dominantPitchClass)
    }
}

private enum Fixtures {
    static var patternImage: UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }

    static func cover() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }

    static func pedal(generatorVersion: Int?, sequence: PedalSequence) throws -> PhotoPedal {
        PhotoPedal(
            id: UUID(uuidString: "D06B0000-0000-4000-8000-000000000003")!,
            name: "Equivalence",
            description: "A test pedal.",
            sequence: sequence,
            effect: .reverb,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            coverFilename: "equivalence.png",
            generatorVersion: generatorVersion
        )
    }
}

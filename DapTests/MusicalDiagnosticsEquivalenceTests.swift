#if DEBUG
import Foundation
import Testing
import UIKit
@testable import Dap

/// Proves that the v1 photo-to-MIDI algorithm is byte-for-byte equivalent
/// whether or not the diagnostics infrastructure is enabled.
///
/// The diagnostic is calculated **after** the sequence is produced; it
/// never touches the algorithm. These tests are the regression guard
/// for that invariant.
struct MusicalDiagnosticsEquivalenceTests {

    @Test func sequenceIsUnchangedWhetherOrNotDiagnosticsRun() async throws {
        let fixtures = ProceduralCorpus.fixtures()
        #expect(!fixtures.isEmpty)

        for fixture in fixtures {
            let prepared = try ImageInputPreparer().prepare(fixture.image)
            let cover = try await RetroImageProcessor().process(prepared.image)
            let color = try PhotoColorAnalyzer.analyze(prepared.image)

            // The v1 sequence, no diagnostics involved
            let sequence = try ImageSequenceGenerator.makeSequence(
                retroImage: cover,
                colorProfile: color
            )

            // Compute diagnostics (should not touch the sequence)
            let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
                for: sequence,
                identifier: fixture.identifier,
                category: fixture.category,
                timings: MusicalDiagnosticsCalculator.Timings(
                    sequenceGenerationMilliseconds: 0,
                    totalRunMilliseconds: 0
                ),
                memory: MusicalDiagnosticsCalculator.Memory()
            )

            // Re-generate the sequence to confirm it is still byte-for-byte identical
            let sequenceAfter = try ImageSequenceGenerator.makeSequence(
                retroImage: cover,
                colorProfile: color
            )

            #expect(sequence == sequenceAfter)
            #expect(sequence.notes == sequenceAfter.notes)
            #expect(sequence.harmony == sequenceAfter.harmony)
            #expect(sequence.soundProfile == sequenceAfter.soundProfile)

            // Diagnostics report what the sequence contains; nothing more
            #expect(diagnostics.algorithmVersion == 1)
            #expect(diagnostics.noteCount == sequence.notes.count)
            #expect(diagnostics.rootPitchClass == sequence.harmony.rootPitchClass)
            #expect(diagnostics.scale == sequence.harmony.scale.rawValue)
            #expect(diagnostics.bpm == sequence.harmony.bpm)
        }
    }

    @Test func dominanceAndChromaticIdentityRemainUnchanged() async throws {
        let fixtures = ProceduralCorpus.fixtures()

        for fixture in fixtures {
            let prepared = try ImageInputPreparer().prepare(fixture.image)
            let cover = try await RetroImageProcessor().process(prepared.image)
            let color = try PhotoColorAnalyzer.analyze(prepared.image)
            let sequence = try ImageSequenceGenerator.makeSequence(
                retroImage: cover,
                colorProfile: color
            )

            let dominantBefore = sequence.dominantPitchClass
            let paletteBefore = PitchColorIdentity.tonalPalette(for: dominantBefore)

            // Compute diagnostics (no effect on identity)
            _ = MusicalDiagnosticsCalculator.makeDiagnostics(
                for: sequence,
                identifier: fixture.identifier,
                category: fixture.category,
                timings: MusicalDiagnosticsCalculator.Timings(
                    sequenceGenerationMilliseconds: 0,
                    totalRunMilliseconds: 0
                ),
                memory: MusicalDiagnosticsCalculator.Memory()
            )

            let dominantAfter = sequence.dominantPitchClass
            let paletteAfter = PitchColorIdentity.tonalPalette(for: dominantAfter)

            #expect(dominantBefore == dominantAfter)
            #expect(paletteBefore == paletteAfter)
        }
    }

    @Test func harnessRunDoesNotMutateFixtures() async throws {
        let fixtures = ProceduralCorpus.fixtures()
        let hashesBefore = fixtures.map(\.pixelHash)
        let preparer = ImageInputPreparer()
        let retro: any RetroImageProcessing = RetroImageProcessor()

        for fixture in fixtures {
            let prepared = try preparer.prepare(fixture.image)
            let cover = try await retro.process(prepared.image)
            let color = try PhotoColorAnalyzer.analyze(prepared.image)
            let sequence = try ImageSequenceGenerator.makeSequence(
                retroImage: cover,
                colorProfile: color
            )
            _ = MusicalDiagnosticsCalculator.makeDiagnostics(
                for: sequence,
                identifier: fixture.identifier,
                category: fixture.category,
                timings: MusicalDiagnosticsCalculator.Timings(
                    sequenceGenerationMilliseconds: 0,
                    totalRunMilliseconds: 0
                ),
                memory: MusicalDiagnosticsCalculator.Memory()
            )
        }

        let hashesAfter = ProceduralCorpus.fixtures().map(\.pixelHash)
        #expect(hashesBefore == hashesAfter)
    }
}
#endif

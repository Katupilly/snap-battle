#if DEBUG
import Foundation
import Testing
@testable import Dap

struct MusicalDiagnosticsCalculatorTests {

    // MARK: - Entropy

    @Test func entropyIsZeroForEmptySequence() {
        let sequence = PedalSequence(
            harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100),
            notes: [],
            soundProfile: .legacy
        )
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "empty",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.pitchClassEntropy == 0)
        #expect(diagnostics.maximumPitchClassShare == 0)
        #expect(diagnostics.noteCount == 0)
        #expect(diagnostics.activeStepCount == 0)
        #expect(diagnostics.meanNotesPerActiveStep == 0)
    }

    @Test func entropyIsZeroForSinglePitchClass() {
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 1, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 2, row: 0, midiNote: 60, velocity: 1)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "monochrome",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.pitchClassEntropy == 0)
        #expect(diagnostics.maximumPitchClassShare == 1)
        #expect(diagnostics.uniquePitchClasses == 1)
    }

    @Test func entropyForUniformDistributionMatchesLogBase2Of12() {
        // One note per pitch class, 12 notes, each bin count = 1.
        let notes = (0..<12).map { pc in
            PedalNote(step: pc, row: 0, midiNote: 60 + pc, velocity: 1)
        }
        let sequence = makeSequence(notes: notes)
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "uniform",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        let expected = log2(Double(12))
        #expect(abs(diagnostics.pitchClassEntropy - expected) < 1e-9)
        #expect(diagnostics.maximumPitchClassShare == 1.0 / 12.0)
        #expect(diagnostics.uniquePitchClasses == 12)
    }

    @Test func pitchClassHistogramSumsToNoteCount() {
        let notes = (0..<8).map { i in
            PedalNote(step: i, row: 0, midiNote: 60 + i, velocity: 1)
        }
        let sequence = makeSequence(notes: notes)
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "hist",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.pitchClassHistogram.count == 12)
        #expect(diagnostics.pitchClassHistogram.reduce(0, +) == diagnostics.noteCount)
        #expect(diagnostics.pitchClassHistogram.reduce(0, +) == 8)
    }

    // MARK: - Intervals

    @Test func intervalsAreZeroForSingleNoteSequence() {
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "single",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.meanIntervalSemitones == 0)
        #expect(diagnostics.maximumJumpSemitones == 0)
        #expect(diagnostics.melodicTransitionCount == 0)
        #expect(diagnostics.zeroIntervalTransitionCount == 0)
        #expect(diagnostics.zeroIntervalTransitionShare == 0)
    }

    @Test func intervalsIgnoreRestsAndUseMostAcuteNotePerStep() {
        // Steps 0, 2, 4 have notes; steps 1, 3 are rests.
        // Step 0 has two notes; the most acute is midiNote 67 (G).
        // Step 2 has midiNote 64 (E).
        // Step 4 has midiNote 60 (C).
        // Expected intervals: |64-67| = 3, |60-64| = 4. Mean = 3.5, max = 4.
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 0, row: 1, midiNote: 67, velocity: 1),
            PedalNote(step: 2, row: 0, midiNote: 64, velocity: 1),
            PedalNote(step: 4, row: 0, midiNote: 60, velocity: 1)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "with-rests",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.restStepCount == PedalSequence.steps - 3) // 13
        #expect(diagnostics.twoVoiceStepCount == 1)
        #expect(diagnostics.zeroIntervalTransitionCount == 0)
        #expect(diagnostics.melodicTransitionCount == 2)
        #expect(abs(diagnostics.meanIntervalSemitones - 3.5) < 1e-9)
        #expect(diagnostics.maximumJumpSemitones == 4)
    }

    @Test func intervalsHandleEmptyRestsSequence() {
        let sequence = makeSequence(notes: [])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "empty-rests",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.restStepCount == PedalSequence.steps)
        #expect(diagnostics.twoVoiceStepCount == 0)
        #expect(diagnostics.threeOrMoreVoiceStepCount == 0)
        #expect(diagnostics.meanIntervalSemitones == 0)
        #expect(diagnostics.maximumJumpSemitones == 0)
        #expect(diagnostics.melodicTransitionCount == 0)
    }

    // MARK: - Step classification

    @Test func restStepAndMultiNoteCountsAreAccurate() {
        // step 0: 1 note
        // step 1: 0 notes
        // step 2: 3 notes
        // step 3: 0 notes
        // step 4: 2 notes
        // rest = 12, single = 1, multi = 2
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 2, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 2, row: 1, midiNote: 62, velocity: 1),
            PedalNote(step: 2, row: 2, midiNote: 64, velocity: 1),
            PedalNote(step: 4, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 4, row: 1, midiNote: 62, velocity: 1)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "multi",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.restStepCount == 13)
        #expect(diagnostics.singleVoiceStepCount == 1)
        #expect(diagnostics.twoVoiceStepCount == 1)
        #expect(diagnostics.threeOrMoreVoiceStepCount == 1)
        #expect(diagnostics.activeStepCount == 3)
        #expect(diagnostics.multiNoteStepShare == 2.0 / 3.0)
    }

    @Test func activeStepCountMatchesStepsMinusRests() {
        // 4 active steps, 12 rests, 8 notes (2 per active step).
        let notes: [PedalNote] = (0..<4).flatMap { step in
            [
                PedalNote(step: step, row: 0, midiNote: 60, velocity: 1),
                PedalNote(step: step, row: 1, midiNote: 62, velocity: 1)
            ]
        }
        let sequence = makeSequence(notes: notes)
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "active",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.activeStepCount == 4)
        #expect(diagnostics.restStepCount == PedalSequence.steps - 4)
        #expect(abs(diagnostics.meanNotesPerActiveStep - 2.0) < 1e-9)
    }

    @Test func meanNotesPerActiveStepIsZeroForAllRestsSequence() {
        let sequence = makeSequence(notes: [])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "all-rests",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.activeStepCount == 0)
        #expect(diagnostics.meanNotesPerActiveStep == 0)
    }

    @Test func voiceDistributionIsIndependentOfNoteOrderWithinAStep() {
        // The same step (step 0) holds three notes regardless of input
        // order. The 3+ voice bucket must remain stable.
        let orderA: [PedalNote] = [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 0, row: 1, midiNote: 62, velocity: 1),
            PedalNote(step: 0, row: 2, midiNote: 64, velocity: 1)
        ]
        let orderB: [PedalNote] = orderA.reversed()
        let sequenceA = makeSequence(notes: orderA)
        let sequenceB = makeSequence(notes: orderB)
        let a = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequenceA,
            identifier: "orderA",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        let b = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequenceB,
            identifier: "orderB",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(a.threeOrMoreVoiceStepCount == b.threeOrMoreVoiceStepCount)
        #expect(a.threeOrMoreVoiceStepCount == 1)
        #expect(a.singleVoiceStepCount == 0)
        #expect(a.twoVoiceStepCount == 0)
    }

    @Test func zeroIntervalTransitionCountsRepeatAcrossMostAcuteSteps() {
        // Step 0 most-acute = 60. Step 1 most-acute = 60 (same). Step 2 most-acute = 62.
        // Transitions: |60-60|=0, |62-60|=2. So 1 zero, 2 total, share 0.5.
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 1, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 2, row: 0, midiNote: 62, velocity: 1)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "zero",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.melodicTransitionCount == 2)
        #expect(diagnostics.zeroIntervalTransitionCount == 1)
        #expect(abs(diagnostics.zeroIntervalTransitionShare - 0.5) < 1e-9)
    }

    @Test func zeroIntervalTransitionShareIsZeroWhenAllTransitionsAreDistinct() {
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 1, row: 0, midiNote: 62, velocity: 1),
            PedalNote(step: 2, row: 0, midiNote: 64, velocity: 1)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "no-zero",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.melodicTransitionCount == 2)
        #expect(diagnostics.zeroIntervalTransitionCount == 0)
        #expect(diagnostics.zeroIntervalTransitionShare == 0)
    }

    // MARK: - Densities

    @Test func noteDensityUsesMaximumNoteSlotsAsDenominator() {
        // One note → 1/128.
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "one-note",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        let expectedDenominator = Double(PedalSequence.maximumNoteSlots)
        #expect(expectedDenominator == 128)
        #expect(abs(diagnostics.noteDensity - 1.0 / expectedDenominator) < 1e-9)
        #expect(abs(diagnostics.restDensity - 15.0 / 16.0) < 1e-9)
    }

    @Test func noteDensityIsZeroForEmptySequenceWithoutDivisionByZero() {
        let sequence = makeSequence(notes: [])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "empty-density",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.noteDensity == 0)
        #expect(diagnostics.noteDensity.isFinite)
        #expect(!diagnostics.noteDensity.isNaN)
    }

    @Test func noteDensityForFullGridEqualsOne() {
        // 16 * 8 = 128 notes → density 1.0.
        var notes: [PedalNote] = []
        for step in 0..<PedalSequence.steps {
            for row in 0..<PedalSequence.rows {
                notes.append(PedalNote(step: step, row: row, midiNote: 60 + row, velocity: 1))
            }
        }
        let sequence = makeSequence(notes: notes)
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "full-grid",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(abs(diagnostics.noteDensity - 1.0) < 1e-9)
        #expect(diagnostics.activeStepCount == PedalSequence.steps)
    }

    // MARK: - Duration histogram

    @Test func durationHistogramBucketsVelocitiesByValue() {
        let sequence = makeSequence(notes: [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 0.5),
            PedalNote(step: 1, row: 0, midiNote: 60, velocity: 0.5),
            PedalNote(step: 2, row: 0, midiNote: 60, velocity: 1.0)
        ])
        let diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: "duration",
            category: nil,
            timings: MusicalDiagnosticsCalculator.Timings(sequenceGenerationMilliseconds: 0, totalRunMilliseconds: 0),
            memory: MusicalDiagnosticsCalculator.Memory()
        )
        #expect(diagnostics.durationHistogram["0.5000"] == 2)
        #expect(diagnostics.durationHistogram["1.0000"] == 1)
    }

    // MARK: - Helpers

    private func makeSequence(notes: [PedalNote]) -> PedalSequence {
        PedalSequence(
            harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100),
            notes: notes,
            soundProfile: .legacy
        )
    }
}
#endif

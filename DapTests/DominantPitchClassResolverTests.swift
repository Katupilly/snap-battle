import Foundation
import Testing
@testable import Dap

struct DominantPitchClassResolverTests {
    @Test func singleNoteResolvesPitchClass() {
        let sequence = makeSequence(notes: [PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)], root: 7)
        #expect(sequence.dominantPitchClass == .c)
    }

    @Test func octavesResolveToSamePitchClass() {
        let notes = [
            PedalNote(step: 0, row: 0, midiNote: 48, velocity: 1),
            PedalNote(step: 1, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 2, row: 0, midiNote: 72, velocity: 1),
        ]
        #expect(makeSequence(notes: notes, root: 5).dominantPitchClass == .c)
    }

    @Test func sparseSequenceIgnoresRestsByCountingOnlyPresentNotes() {
        let notes = [
            PedalNote(step: 0, row: 0, midiNote: 62, velocity: 1),
            PedalNote(step: 8, row: 0, midiNote: 62, velocity: 1),
            PedalNote(step: 15, row: 0, midiNote: 64, velocity: 1),
        ]
        #expect(makeSequence(notes: notes, root: 0).dominantPitchClass == .d)
    }

    @Test func chordCountsEveryNoteIndividually() {
        let notes = [
            PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1),
            PedalNote(step: 0, row: 1, midiNote: 64, velocity: 1),
            PedalNote(step: 0, row: 2, midiNote: 67, velocity: 1),
            PedalNote(step: 1, row: 0, midiNote: 67, velocity: 1),
            PedalNote(step: 2, row: 0, midiNote: 67, velocity: 1),
        ]
        #expect(makeSequence(notes: notes, root: 0).dominantPitchClass == .g)
    }

    @Test func tieBreakUsesFirstTemporalOccurrence() {
        let notes = [
            PedalNote(step: 0, row: 1, midiNote: 62, velocity: 1), // D
            PedalNote(step: 1, row: 0, midiNote: 60, velocity: 1), // C
            PedalNote(step: 2, row: 0, midiNote: 60, velocity: 1), // C
            PedalNote(step: 3, row: 0, midiNote: 62, velocity: 1), // D
        ]
        #expect(makeSequence(notes: notes, root: 0).dominantPitchClass == .d)
    }

    @Test func tieBreakWithThreePitchClassesUsesFirstOccurrence() {
        let notes = [
            PedalNote(step: 2, row: 0, midiNote: 60, velocity: 1), // C
            PedalNote(step: 0, row: 0, midiNote: 64, velocity: 1), // E
            PedalNote(step: 1, row: 0, midiNote: 67, velocity: 1), // G
            PedalNote(step: 3, row: 0, midiNote: 64, velocity: 1),
            PedalNote(step: 4, row: 0, midiNote: 67, velocity: 1),
            PedalNote(step: 5, row: 0, midiNote: 60, velocity: 1),
        ]
        #expect(makeSequence(notes: notes, root: 0).dominantPitchClass == .e)
    }

    @Test func simultaneousTieUsesCanonicalOrdering() {
        let notes = [
            PedalNote(step: 0, row: 4, midiNote: 67, velocity: 1), // G appears later row
            PedalNote(step: 0, row: 1, midiNote: 60, velocity: 1), // C appears earlier row
            PedalNote(step: 1, row: 0, midiNote: 67, velocity: 1),
            PedalNote(step: 1, row: 1, midiNote: 60, velocity: 1),
        ]
        #expect(makeSequence(notes: notes, root: 9).dominantPitchClass == .c)
    }

    @Test func emptySequenceFallsBackToHarmonyRootPitchClass() {
        let sequence = makeSequence(notes: [], root: 9)
        #expect(sequence.dominantPitchClass == .a)
    }

    @Test func invalidHarmonyRootFallsBackToC() {
        let sequence = makeSequence(notes: [], root: 99)
        #expect(sequence.dominantPitchClass == .c)
    }

    @Test func resolutionIsStableAcrossRepeatedRuns() {
        let notes = [
            PedalNote(step: 0, row: 0, midiNote: 70, velocity: 1), // A#
            PedalNote(step: 1, row: 0, midiNote: 58, velocity: 1), // A#
            PedalNote(step: 2, row: 0, midiNote: 61, velocity: 1), // C#
        ]
        let sequence = makeSequence(notes: notes, root: 0)
        let first = sequence.dominantPitchClass
        let second = sequence.dominantPitchClass
        let third = sequence.dominantPitchClass
        #expect(first == .aSharp)
        #expect(first == second)
        #expect(second == third)
    }

    @Test func allPitchClassesCanBeResolved() {
        for pitch in PitchClass.allCases {
            let sequence = makeSequence(notes: [PedalNote(step: 0, row: 0, midiNote: 60 + pitch.rawValue, velocity: 1)], root: 0)
            #expect(sequence.dominantPitchClass == pitch)
        }
    }

    private func makeSequence(notes: [PedalNote], root: Int) -> PedalSequence {
        PedalSequence(
            harmony: PedalHarmony(rootPitchClass: root, scale: .majorPentatonic, bpm: 100),
            notes: notes,
            soundProfile: .legacy
        )
    }
}

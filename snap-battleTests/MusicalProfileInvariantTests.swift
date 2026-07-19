import Foundation
import Testing
@testable import snap_battle

/// Invariant tests for `MusicalProfile`.
///
/// Reference:
/// - `specs/current/photo-midi-variety-v2.md` §9.2
/// - `specs/current/photo-midi-variety-v2-incremento-2.md` §6.3
struct MusicalProfileInvariantTests {

    @Test func validProfilePassesValidation() throws {
        let profile = Fixtures.validProfile
        try profile.validate()
    }

    @Test func generationSeedIsZeroPlaceholder() throws {
        let profile = Fixtures.validProfile
        #expect(profile.generationSeed == 0)
    }

    @Test func tonalFamilyIsNeutralPlaceholder() throws {
        let profile = Fixtures.validProfile
        #expect(profile.tonalFamily == .neutral)
    }

    @Test func allMelodicContourCasesAreConstructable() throws {
        for contour in MelodicContour.allCases {
            var profile = Fixtures.validProfile
            profile = MusicalProfile(
                rootPitchClass: profile.rootPitchClass,
                scale: profile.scale,
                register: profile.register,
                density: profile.density,
                syncopation: profile.syncopation,
                intervalRange: profile.intervalRange,
                repetitionFactor: profile.repetitionFactor,
                tension: profile.tension,
                contour: contour,
                bpm: profile.bpm,
                baseOctave: profile.baseOctave,
                timeSignatureSteps: profile.timeSignatureSteps,
                generationSeed: profile.generationSeed,
                tonalFamily: profile.tonalFamily
            )
            try profile.validate()
            #expect(profile.contour == contour)
        }
    }

    @Test func allTonalFamilyCasesAreConstructable() throws {
        for family in TonalFamily.allCases {
            var profile = Fixtures.validProfile
            profile = MusicalProfile(
                rootPitchClass: profile.rootPitchClass,
                scale: profile.scale,
                register: profile.register,
                density: profile.density,
                syncopation: profile.syncopation,
                intervalRange: profile.intervalRange,
                repetitionFactor: profile.repetitionFactor,
                tension: profile.tension,
                contour: profile.contour,
                bpm: profile.bpm,
                baseOctave: profile.baseOctave,
                timeSignatureSteps: profile.timeSignatureSteps,
                generationSeed: profile.generationSeed,
                tonalFamily: family
            )
            try profile.validate()
            #expect(profile.tonalFamily == family)
        }
    }

    @Test func rawValueAndOrderAreFrozenForMelodicContour() {
        #expect(MelodicContour.allCases.map(\.rawValue) == [
            "ascending", "descending", "arched", "stable", "meandering"
        ])
    }

    @Test func rawValueAndOrderAreFrozenForTonalFamily() {
        #expect(TonalFamily.allCases.map(\.rawValue) == [
            "warm", "cool", "green", "purple", "neutral", "lowSaturation", "highSaturation"
        ])
    }

    @Test func codableRoundTripForEnums() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for contour in MelodicContour.allCases {
            let data = try encoder.encode(contour)
            let decoded = try decoder.decode(MelodicContour.self, from: data)
            #expect(decoded == contour)
        }
        for family in TonalFamily.allCases {
            let data = try encoder.encode(family)
            let decoded = try decoder.decode(TonalFamily.self, from: data)
            #expect(decoded == family)
        }
    }

    @Test func bpmOutOfRangeFails() {
        let profile = Fixtures.profileWith(bpm: 60)
        #expect(throws: VisualAnalysisError.self) { try profile.validate() }
    }

    @Test func baseOctaveOutOfSetFails() {
        let profile = Fixtures.profileWith(baseOctave: 3)
        #expect(throws: VisualAnalysisError.self) { try profile.validate() }
    }

    @Test func timeSignatureStepsMustBe16() {
        let profile = Fixtures.profileWith(timeSignatureSteps: 8)
        #expect(throws: VisualAnalysisError.self) { try profile.validate() }
    }
}

private enum Fixtures {
    static let validProfile = MusicalProfile(
        rootPitchClass: PitchClass.c,
        scale: .majorPentatonic,
        register: 24...48,
        density: 0.65,
        syncopation: 0.3,
        intervalRange: 1...12,
        repetitionFactor: 0.5,
        tension: 0.4,
        contour: .ascending,
        bpm: 100,
        baseOctave: 4,
        timeSignatureSteps: 16,
        generationSeed: 0,
        tonalFamily: .neutral
    )

    static func profileWith(
        rootPitchClass: PitchClass = PitchClass.c,
        scale: PedalScale = .majorPentatonic,
        register: ClosedRange<Int> = 24...48,
        density: Double = 0.65,
        syncopation: Double = 0.3,
        intervalRange: ClosedRange<Int> = 1...12,
        repetitionFactor: Double = 0.5,
        tension: Double = 0.4,
        contour: MelodicContour = .ascending,
        bpm: Int = 100,
        baseOctave: Int = 4,
        timeSignatureSteps: Int = 16,
        generationSeed: UInt64 = 0,
        tonalFamily: TonalFamily = .neutral
    ) -> MusicalProfile {
        MusicalProfile(
            rootPitchClass: rootPitchClass,
            scale: scale,
            register: register,
            density: density,
            syncopation: syncopation,
            intervalRange: intervalRange,
            repetitionFactor: repetitionFactor,
            tension: tension,
            contour: contour,
            bpm: bpm,
            baseOctave: baseOctave,
            timeSignatureSteps: timeSignatureSteps,
            generationSeed: generationSeed,
            tonalFamily: tonalFamily
        )
    }
}

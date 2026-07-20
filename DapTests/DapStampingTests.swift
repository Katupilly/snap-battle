//
//  DapStampingTests.swift
//  DapTests
//

import Foundation
import Testing
@testable import Dap

/// Round-trip stamping tests for `PhotoPedal` JSON encoding.
///
/// Reference:
/// - `specs/current/photo-midi-variety-v2.md` §13.10
/// - `specs/current/photo-midi-variety-v2-incremento-2.md` §12
struct DapStampingTests {

    @Test func newPedalDefaultsToGeneratorVersionOne() {
        // Verify the memberwise init default by constructing without
        // explicitly supplying `generatorVersion`.
        let pedal = PhotoPedal(
            id: UUID(uuidString: "D06B0000-0000-4000-8000-000000000020")!,
            name: "Default Pedal",
            description: "Constructed without explicit generatorVersion.",
            sequence: PedalSequence(
                harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100),
                notes: [PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)],
                soundProfile: .legacy
            ),
            effect: .reverb,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            coverFilename: "default.png"
        )
        #expect(pedal.generatorVersion == 1)
    }

    @Test func newPedalEncodesAsIntegerOne() throws {
        let pedal = Fixtures.makePedal(explicitVersion: 1)
        let data = try JSONEncoder().encode(pedal)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["generatorVersion"] as? Int == 1)
    }

    @Test func legacyDecodesToNilAndReencodesWithoutTheField() throws {
        let data = try Fixtures.legacyJSONData(generatorVersion: .absent)
        let decoded = try JSONDecoder().decode(PhotoPedal.self, from: data)
        #expect(decoded.generatorVersion == nil)
        let recoded = try JSONEncoder().encode(decoded)
        let json = try #require(try JSONSerialization.jsonObject(with: recoded) as? [String: Any])
        #expect(json["generatorVersion"] == nil)
    }

    @Test func nilInJSONDecodesAsNil() throws {
        let data = try Fixtures.legacyJSONData(generatorVersion: .null)
        let decoded = try JSONDecoder().decode(PhotoPedal.self, from: data)
        #expect(decoded.generatorVersion == nil)
    }

    @Test func unknownIntegerVersionIsPreservedOnRoundTrip() throws {
        for value in [2, 3, 99, -1, 1_000_000] {
            let data = try Fixtures.legacyJSONData(generatorVersion: .int(value))
            let decoded = try JSONDecoder().decode(PhotoPedal.self, from: data)
            #expect(decoded.generatorVersion == value)
            let recoded = try JSONEncoder().encode(decoded)
            let json = try #require(try JSONSerialization.jsonObject(with: recoded) as? [String: Any])
            #expect(json["generatorVersion"] as? Int == value)
        }
    }

    @Test func updatingMetadataPreservesOne() {
        let pedal = Fixtures.makePedal(explicitVersion: 1)
        let updated = pedal.updatingMetadata(name: "Renamed", description: "New description.")
        #expect(updated.generatorVersion == 1)
    }

    @Test func updatingMetadataPreservesNil() {
        let pedal = Fixtures.makePedal(explicitVersion: nil)
        let updated = pedal.updatingMetadata(name: "Renamed", description: "New description.")
        #expect(updated.generatorVersion == nil)
    }

    @Test func updatingMetadataPreservesUnknownValue() {
        let pedal = Fixtures.makePedal(explicitVersion: 99)
        let updated = pedal.updatingMetadata(name: "Renamed", description: "New description.")
        #expect(updated.generatorVersion == 99)
    }

    @Test func updatingEffectAndSoundProfilePreservesOne() {
        let pedal = Fixtures.makePedal(explicitVersion: 1)
        let updated = pedal.updating(effect: .distortion, soundProfile: .legacy)
        #expect(updated.generatorVersion == 1)
        #expect(updated.effect == .distortion)
    }

    @Test func updatingEffectAndSoundProfilePreservesNil() {
        let pedal = Fixtures.makePedal(explicitVersion: nil)
        let updated = pedal.updating(effect: .distortion, soundProfile: .legacy)
        #expect(updated.generatorVersion == nil)
    }
}

private enum Fixtures {
    static func makePedal(explicitVersion: Int?) -> PhotoPedal {
        let sequence = PedalSequence(
            harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100),
            notes: [PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)],
            soundProfile: .legacy
        )
        return PhotoPedal(
            id: UUID(uuidString: "D06B0000-0000-4000-8000-000000000010")!,
            name: "Stamping Pedal",
            description: "Used by the stamping tests.",
            sequence: sequence,
            effect: .reverb,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            coverFilename: "stamping.png",
            generatorVersion: explicitVersion
        )
    }

    enum GeneratorVersionValue { case absent, `null`, int(Int) }

    static func legacyJSONData(generatorVersion: GeneratorVersionValue) throws -> Data {
        var dict: [String: Any] = [
            "id": "D06B0000-0000-4000-8000-000000000011",
            "name": "Legacy",
            "description": "Pre-Increment-2 pedal.",
            "effect": "reverb",
            "createdAt": 1_000_000.0,
            "coverFilename": "legacy.png",
            "sequence": [
                "harmony": [
                    "rootPitchClass": 0,
                    "scale": "majorPentatonic",
                    "bpm": 100
                ],
                "notes": [[
                    "step": 0,
                    "row": 0,
                    "midiNote": 60,
                    "velocity": 1
                ]],
                "soundProfile": [
                    "gate": 1,
                    "octaveRange": 1,
                    "waveform": "square",
                    "reverbPreset": "mediumRoom",
                    "distortionPreset": "multiEcho1",
                    "defaultReverbMix": 48,
                    "defaultDistortionMix": 55,
                    "reverbMix": 48,
                    "distortionMix": 55
                ]
            ]
        ]
        switch generatorVersion {
        case .absent:
            break
        case .null:
            dict["generatorVersion"] = NSNull()
        case .int(let value):
            dict["generatorVersion"] = value
        }
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

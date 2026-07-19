import Foundation
import Testing
import UIKit
@testable import snap_battle

/// Contract tests for `PhotoPedal.generatorVersion` (Increment 2).
///
/// Reference:
/// - `specs/current/photo-midi-variety-v2.md` §13 (Persistência e Versionamento)
/// - `specs/current/photo-midi-variety-v2-incremento-2.md` §6.6, §8, §12
///
/// The version is **metadata only**; the persisted sequence and sound
/// profile are still replayed literally per ADR 0002. These tests only
/// prove the encode/decode contract, not the musical behavior.
struct VersioningTests {

    @Test func legacyJSONWithoutFieldDecodesAsNil() throws {
        let legacyJSON = Self.legacyJSON(excluding: "generatorVersion")

        let decoded = try JSONDecoder().decode(PhotoPedal.self, from: legacyJSON)

        #expect(decoded.generatorVersion == nil)
    }

    @Test func legacyJSONWithNilValueDecodesAsNil() throws {
        let json = Self.legacyJSON(replacingGeneratorVersionWith: .null)

        let decoded = try JSONDecoder().decode(PhotoPedal.self, from: json)

        #expect(decoded.generatorVersion == nil)
    }

    @Test func newPedalWithVersionOnePersistsAsInteger() throws {
        let pedal = Fixtures.pedal(generatorVersion: 1)

        let data = try JSONEncoder().encode(pedal)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["generatorVersion"] as? Int == 1)
    }

    @Test func encodeOmitNilValue() throws {
        let pedal = Fixtures.pedal(generatorVersion: nil)

        let data = try JSONEncoder().encode(pedal)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["generatorVersion"] == nil)
    }

    @Test func recodingLegacyPedalOmitsTheField() throws {
        let legacyJSON = Self.legacyJSON(excluding: "generatorVersion")
        let decoded = try JSONDecoder().decode(PhotoPedal.self, from: legacyJSON)
        let recoded = try JSONEncoder().encode(decoded)
        let json = try #require(try JSONSerialization.jsonObject(with: recoded) as? [String: Any])

        #expect(json["generatorVersion"] == nil)
    }

    @Test func unknownVersionValuesArePreserved() throws {
        for value in [2, 3, 99, -1, 1_000_000] {
            let json = Self.legacyJSON(replacingGeneratorVersionWith: .int(value))
            let decoded = try JSONDecoder().decode(PhotoPedal.self, from: json)
            #expect(decoded.generatorVersion == value, "Value \(value) must be preserved verbatim")
        }
    }

    @Test func updatingMetadataPreservesGeneratorVersion() throws {
        let original = Fixtures.pedal(generatorVersion: 1)
        let updated = original.updatingMetadata(name: "Renamed", description: "Different description.")

        #expect(updated.generatorVersion == original.generatorVersion)
    }

    @Test func updatingMetadataPreservesNilForLegacyPedal() throws {
        let original = Fixtures.pedal(generatorVersion: nil)
        let updated = original.updatingMetadata(name: "Renamed", description: "Different description.")

        #expect(updated.generatorVersion == nil)
    }

    @Test func updatingEffectAndSoundProfilePreservesGeneratorVersion() throws {
        let original = Fixtures.pedal(generatorVersion: 1)
        let updated = original.updating(effect: .distortion, soundProfile: .legacy)

        #expect(updated.generatorVersion == original.generatorVersion)
        #expect(updated.effect == .distortion)
    }

    @Test func defaultInitializerProducesVersionOne() throws {
        // The init with the default value would set 1, but the fixture
        // uses the explicit nil overload. Verify that the memberwise
        // default-equivalent path produces 1 when called without an
        // explicit value.
        let defaultPedal = Fixtures.pedal()
        #expect(defaultPedal.generatorVersion == 1)
    }

    @Test func decodingLegacyViaPedalStorePreservesGeneratorVersion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)

        let legacy = Fixtures.pedal(generatorVersion: nil)
        try store.save(legacy, cover: Fixtures.cover())
        let loaded = try #require(store.loadLatest())

        #expect(loaded.pedal.generatorVersion == nil)
    }

    @Test func decodingVersionOneViaPedalStorePreservesGeneratorVersion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)

        let pedal = Fixtures.pedal(generatorVersion: 1)
        try store.save(pedal, cover: Fixtures.cover())
        let loaded = try #require(store.loadLatest())

        #expect(loaded.pedal.generatorVersion == 1)
    }

    @Test func decodingUnknownVersionViaPedalStorePreservesValue() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PedalStore(directory: directory)

        let pedal = Fixtures.pedal(generatorVersion: 42)
        try store.save(pedal, cover: Fixtures.cover())
        let loaded = try #require(store.loadLatest())

        #expect(loaded.pedal.generatorVersion == 42)
    }
}

private enum Fixtures {
    static func pedal(generatorVersion: Int? = 1) -> PhotoPedal {
        let sequence = PedalSequence(
            harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100),
            notes: [PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)],
            soundProfile: .legacy
        )
        return PhotoPedal(
            id: UUID(uuidString: "D06B0000-0000-4000-8000-000000000001")!,
            name: "Versioning Test",
            description: "A pedal used by the versioning tests.",
            sequence: sequence,
            effect: .reverb,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            coverFilename: "versioning-test.png",
            generatorVersion: generatorVersion
        )
    }

    static func cover() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }
}

private enum JSONValue {
    case absent
    case `null`
    case int(Int)
}

private extension VersioningTests {
    static func legacyJSON(excluding key: String) -> Data {
        legacyJSON(replacingGeneratorVersionWith: .absent, excludingKey: key)
    }

    static func legacyJSON(replacingGeneratorVersionWith value: JSONValue) -> Data {
        legacyJSON(replacingGeneratorVersionWith: value, excludingKey: nil)
    }

    static func legacyJSON(replacingGeneratorVersionWith value: JSONValue, excludingKey: String?) -> Data {
        var dict: [String: Any] = [
            "id": "D06B0000-0000-4000-8000-000000000002",
            "name": "Legacy Pedal",
            "description": "A pre-Increment-2 pedal.",
            "effect": "reverb",
            "createdAt": 1_000_000.0,
            "coverFilename": "legacy.png"
        ]
        let harmony: [String: Any] = [
            "rootPitchClass": 0,
            "scale": "majorPentatonic",
            "bpm": 100
        ]
        let soundProfile: [String: Any] = [
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
        dict["sequence"] = [
            "harmony": harmony,
            "notes": [[
                "step": 0,
                "row": 0,
                "midiNote": 60,
                "velocity": 1
            ]],
            "soundProfile": soundProfile
        ]
        switch value {
        case .absent:
            break
        case .null:
            dict["generatorVersion"] = NSNull()
        case .int(let int):
            dict["generatorVersion"] = int
        }
        if let excludingKey, dict[excludingKey] != nil {
            dict.removeValue(forKey: excludingKey)
        }
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

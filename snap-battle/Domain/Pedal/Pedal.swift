import Foundation
import FoundationModels

enum PedalScale: String, Codable, Sendable, CaseIterable {
    case majorPentatonic, minorPentatonic, dorian, wholeTone

    var degrees: [Int] {
        switch self {
        case .majorPentatonic: [0, 2, 4, 7, 9]
        case .minorPentatonic: [0, 3, 5, 7, 10]
        case .dorian: [0, 2, 3, 5, 7, 9, 10]
        case .wholeTone: [0, 2, 4, 6, 8, 10]
        }
    }

    var displayName: String {
        switch self {
        case .majorPentatonic: "Pentatônica maior"
        case .minorPentatonic: "Pentatônica menor"
        case .dorian: "Dórico"
        case .wholeTone: "Tons inteiros"
        }
    }
}

enum PedalEffect: String, Codable, Sendable, CaseIterable, Identifiable { case reverb, distortion
    var id: String { rawValue }
    var displayName: String { self == .reverb ? "Reverb" : "Distortion" }
    var symbolName: String { self == .reverb ? "waveform.path.ecg" : "waveform.badge.plus" }
}

enum PedalWaveform: String, Codable, Sendable { case square, triangle }
enum PedalReverbPreset: String, Codable, Sendable { case smallRoom, mediumRoom, cathedral }
enum PedalDistortionPreset: String, Codable, Sendable { case multiEcho1, drumsBitBrush }

struct PedalSoundProfile: Codable, Sendable, Equatable {
    let gate: Double
    let octaveRange: Double
    let waveform: PedalWaveform
    let reverbPreset: PedalReverbPreset
    let distortionPreset: PedalDistortionPreset
    let defaultReverbMix: Double
    let defaultDistortionMix: Double
    let reverbMix: Double
    let distortionMix: Double

    func updatingMix(_ mix: Double, for effect: PedalEffect) -> Self {
        Self(gate: gate, octaveRange: octaveRange, waveform: waveform, reverbPreset: reverbPreset, distortionPreset: distortionPreset, defaultReverbMix: defaultReverbMix, defaultDistortionMix: defaultDistortionMix, reverbMix: effect == .reverb ? mix : reverbMix, distortionMix: effect == .distortion ? mix : distortionMix)
    }

    func mix(for effect: PedalEffect) -> Double { effect == .reverb ? reverbMix : distortionMix }

    static let legacy = PedalSoundProfile(gate: 1, octaveRange: 1, waveform: .square, reverbPreset: .mediumRoom, distortionPreset: .multiEcho1, defaultReverbMix: 48, defaultDistortionMix: 55, reverbMix: 48, distortionMix: 55)
}

struct PedalHarmony: Codable, Sendable, Equatable {
    let rootPitchClass: Int
    let scale: PedalScale
    let bpm: Int
    var rootName: String { ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][max(0, min(11, rootPitchClass))] }
}

struct PedalNote: Codable, Sendable, Equatable, Identifiable {
    let step: Int; let row: Int; let midiNote: Int; let velocity: Float
    var id: String { "\(step)-\(row)" }
}

struct PedalSequence: Codable, Sendable, Equatable {
    static let steps = 16; static let rows = 8
    let harmony: PedalHarmony
    let notes: [PedalNote]
    let soundProfile: PedalSoundProfile

    private enum CodingKeys: String, CodingKey { case harmony, notes, soundProfile }
    init(harmony: PedalHarmony, notes: [PedalNote], soundProfile: PedalSoundProfile) {
        self.harmony = harmony; self.notes = notes; self.soundProfile = soundProfile
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        harmony = try container.decode(PedalHarmony.self, forKey: .harmony)
        notes = try container.decode([PedalNote].self, forKey: .notes)
        soundProfile = try container.decodeIfPresent(PedalSoundProfile.self, forKey: .soundProfile) ?? .legacy
    }
}

struct PhotoPedal: Codable, Sendable, Equatable, Identifiable {
    let id: UUID; let name: String; let description: String; let sequence: PedalSequence
    let effect: PedalEffect; let createdAt: Date; let coverFilename: String

    func updating(effect: PedalEffect? = nil, soundProfile: PedalSoundProfile? = nil) -> Self {
        Self(id: id, name: name, description: description, sequence: PedalSequence(harmony: sequence.harmony, notes: sequence.notes, soundProfile: soundProfile ?? sequence.soundProfile), effect: effect ?? self.effect, createdAt: createdAt, coverFilename: coverFilename)
    }
}

@Generable(description: "A concise, evocative name and one-sentence description for a photo-generated sound pedal.")
struct PedalDraft: Sendable, Equatable {
    @Guide(description: "A memorable evocative pedal name, at most 24 characters") var name: String
    @Guide(description: "One poetic, family-friendly sentence describing the pedal sound, at most 140 characters") var description: String
}

struct PedalDraftValidator: Sendable {
    func validate(_ draft: PedalDraft) throws -> PedalDraft {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines), description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 24, !description.isEmpty, description.count <= 140 else { throw AppError.invalidDraft }
        return PedalDraft(name: name, description: description)
    }
}

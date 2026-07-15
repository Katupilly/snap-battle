import Foundation

enum PedalScale: String, Codable, Sendable, CaseIterable {
    case majorPentatonic
    case minorPentatonic

    var intervals: [Int] {
        switch self {
        case .majorPentatonic: [0, 2, 4, 7, 9, 12, 14, 16]
        case .minorPentatonic: [0, 3, 5, 7, 10, 12, 15, 17]
        }
    }

    var displayName: String { self == .majorPentatonic ? "Pentatônica maior" : "Pentatônica menor" }
}

enum PedalEffect: String, Codable, Sendable, CaseIterable, Identifiable {
    case reverb
    case distortion

    var id: String { rawValue }
    var displayName: String { self == .reverb ? "Reverb" : "Distortion" }
    var symbolName: String { self == .reverb ? "waveform.path.ecg" : "waveform.badge.plus" }
}

struct PedalHarmony: Codable, Sendable, Equatable {
    let rootPitchClass: Int
    let scale: PedalScale
    let bpm: Int

    var rootName: String { ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][max(0, min(11, rootPitchClass))] }
}

struct PedalNote: Codable, Sendable, Equatable, Identifiable {
    let step: Int
    let row: Int
    let midiNote: Int
    let velocity: Float

    var id: String { "\(step)-\(row)" }
}

struct PedalSequence: Codable, Sendable, Equatable {
    static let steps = 16
    static let rows = 8
    let harmony: PedalHarmony
    let notes: [PedalNote]
}

struct PhotoPedal: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let sequence: PedalSequence
    let effect: PedalEffect
    let createdAt: Date
    let coverFilename: String
}

import FoundationModels

@Generable(description: "A concise, evocative name and one-sentence description for a photo-generated sound pedal.")
struct PedalDraft: Sendable, Equatable {
    @Guide(description: "A memorable evocative pedal name, at most 24 characters") var name: String
    @Guide(description: "One poetic, family-friendly sentence describing the pedal sound, at most 140 characters") var description: String
}

struct PedalDraftValidator: Sendable {
    func validate(_ draft: PedalDraft) throws -> PedalDraft {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 24, !description.isEmpty, description.count <= 140 else {
            throw AppError.invalidDraft
        }
        return PedalDraft(name: name, description: description)
    }
}

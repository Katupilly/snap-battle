import Foundation

enum PedalPlaybackTimingError: LocalizedError, Equatable, Sendable {
    case invalidSampleRate(Double)
    case invalidBPM(Int)
    case invalidGate(Double)
    case invalidNote(step: Int, row: Int)

    var errorDescription: String? {
        switch self {
        case .invalidSampleRate(let sampleRate):
            "Invalid sample rate: \(sampleRate)."
        case .invalidBPM(let bpm):
            "Invalid BPM: \(bpm)."
        case .invalidGate(let gate):
            "Invalid gate: \(gate)."
        case .invalidNote(let step, let row):
            "Invalid note position: step \(step), row \(row)."
        }
    }
}

enum PedalPlaybackTiming {
    static func validate(_ sequence: PedalSequence, sampleRate: Double) throws {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw PedalPlaybackTimingError.invalidSampleRate(sampleRate)
        }
        guard sequence.harmony.bpm > 0 else {
            throw PedalPlaybackTimingError.invalidBPM(sequence.harmony.bpm)
        }
        guard sequence.soundProfile.gate.isFinite,
              sequence.soundProfile.gate > 0,
              sequence.soundProfile.gate <= 1 else {
            throw PedalPlaybackTimingError.invalidGate(sequence.soundProfile.gate)
        }
        for note in sequence.notes where note.step < 0 || note.step >= PedalSequence.steps || note.row < 0 || note.row >= PedalSequence.rows {
            throw PedalPlaybackTimingError.invalidNote(step: note.step, row: note.row)
        }
    }

    static func samplesPerStep(sequence: PedalSequence, sampleRate: Double) -> Int {
        max(1, Int(sampleRate * 60 / Double(sequence.harmony.bpm) / 4))
    }

    static func duration(sequence: PedalSequence, sampleRate: Double, stepCount: Int = PedalSequence.steps) throws -> TimeInterval {
        try validate(sequence, sampleRate: sampleRate)
        let totalSamples = samplesPerStep(sequence: sequence, sampleRate: sampleRate) * stepCount
        return Double(totalSamples) / sampleRate
    }
}

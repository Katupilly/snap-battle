import Foundation

nonisolated enum DominantPitchClassResolver {
    nonisolated static func resolve(sequence: PedalSequence) -> PitchClass {
        let orderedNotes = sequence.notes.enumerated().sorted { lhs, rhs in
            if lhs.element.step != rhs.element.step { return lhs.element.step < rhs.element.step }
            if lhs.element.row != rhs.element.row { return lhs.element.row < rhs.element.row }
            return lhs.offset < rhs.offset
        }

        guard !orderedNotes.isEmpty else {
            return PitchClass(rawValue: sequence.harmony.rootPitchClass) ?? .c
        }

        var counts: [PitchClass: Int] = [:]
        var firstOccurrenceIndex: [PitchClass: Int] = [:]

        for (index, noteWithPosition) in orderedNotes.enumerated() {
            let pitchClass = PitchClass(midiNote: noteWithPosition.element.midiNote)
            counts[pitchClass, default: 0] += 1
            if firstOccurrenceIndex[pitchClass] == nil {
                firstOccurrenceIndex[pitchClass] = index
            }
        }

        let winner = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            let lhsFirst = firstOccurrenceIndex[lhs.key] ?? .max
            let rhsFirst = firstOccurrenceIndex[rhs.key] ?? .max
            return lhsFirst > rhsFirst
        }?.key

        return winner ?? (PitchClass(rawValue: sequence.harmony.rootPitchClass) ?? .c)
    }
}

extension PedalSequence {
    nonisolated var dominantPitchClass: PitchClass {
        DominantPitchClassResolver.resolve(sequence: self)
    }
}

extension PhotoPedal {
    nonisolated var dominantPitchClass: PitchClass {
        sequence.dominantPitchClass
    }
}

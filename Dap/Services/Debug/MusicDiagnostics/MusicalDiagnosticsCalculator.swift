#if DEBUG
import CoreGraphics
import Foundation

/// Pure calculator that turns a `PedalSequence` into `MusicalRunDiagnostics`.
///
/// The calculator never mutates the sequence, never re-runs the v1
/// algorithm, and never inspects the source image. It is intended to
/// be cheap enough to call from a hot loop over a corpus.
///
/// All exported functions are deterministic: given the same `PedalSequence`
/// and identifier, the resulting `MusicalRunDiagnostics` is byte-for-byte
/// identical across runs and platforms.
enum MusicalDiagnosticsCalculator {

    // MARK: - Public API

    /// Build a `MusicalRunDiagnostics` for a single sequence.
    ///
    /// - Parameters:
    ///   - sequence: the v1-generated sequence.
    ///   - identifier: stable identifier (e.g. `portraitDay-001`).
    ///   - category: optional primary category.
    ///   - timings: pre-measured durations for the three pipeline stages.
    ///   - memory: pre-measured resident memory samples.
    static func makeDiagnostics(
        for sequence: PedalSequence,
        identifier: String,
        category: CorpusCategory?,
        timings: Timings,
        memory: Memory
    ) -> MusicalRunDiagnostics {
        let calculationStart = ContinuousClock.now
        let noteCount = sequence.notes.count
        let steps = PedalSequence.steps

        // Step-level classification
        var notesPerStep: [Int] = Array(repeating: 0, count: steps)
        for note in sequence.notes {
            if (0..<steps).contains(note.step) {
                notesPerStep[note.step] += 1
            }
        }
        let restStepCount = notesPerStep.filter { $0 == 0 }.count
        let activeStepCount = steps - restStepCount
        let singleVoiceStepCount = notesPerStep.filter { $0 == 1 }.count
        let twoVoiceStepCount = notesPerStep.filter { $0 == 2 }.count
        let threeOrMoreVoiceStepCount = notesPerStep.filter { $0 >= 3 }.count
        let multiNoteStepCount = twoVoiceStepCount + threeOrMoreVoiceStepCount

        // Pitch class histogram and unique counts
        var pitchClassHistogram: [Int] = Array(repeating: 0, count: 12)
        var uniqueMIDINotes = Set<Int>()
        var uniquePitchClasses = Set<Int>()
        for note in sequence.notes {
            let pc = ((note.midiNote % 12) + 12) % 12
            pitchClassHistogram[pc] += 1
            uniqueMIDINotes.insert(note.midiNote)
            uniquePitchClasses.insert(pc)
        }

        let pitchClassEntropy = entropy(from: pitchClassHistogram, total: noteCount)
        let maximumPitchClassShare: Double = noteCount == 0
            ? 0
            : Double(pitchClassHistogram.max() ?? 0) / Double(noteCount)

        // Intervals: most-acute note per step. The same melodic policy
        // is used for mean/max/zero transitions so the shares are
        // consistent.
        let intervals = mostAcuteIntervals(sequence: sequence, steps: steps)
        let zeroIntervals = intervals.filter { $0 == 0 }.count
        let melodicTransitionCount = intervals.count
        let (meanInterval, maxJump) = intervalStats(intervals: intervals)
        let zeroIntervalTransitionShare: Double = melodicTransitionCount == 0
            ? 0
            : Double(zeroIntervals) / Double(melodicTransitionCount)

        // Duration histogram (velocity buckets)
        let durationHistogram = durationHistogram(sequence: sequence)

        // Mean notes per active step. `noteCount == 0` implies
        // `activeStepCount == 0`, but the guard is kept explicit.
        let meanNotesPerActiveStep: Double = activeStepCount == 0
            ? 0
            : Double(noteCount) / Double(activeStepCount)

        // Densities. `noteDensity` is normalized against the structural
        // upper bound `PedalSequence.maximumNoteSlots = steps * rows`
        // (currently `16 * 8 = 128`). This is the maximum number of
        // notes a v1 sequence can carry if every cell is filled.
        let maximumNoteSlots = Double(PedalSequence.maximumNoteSlots)
        let noteDensity: Double = noteCount == 0
            ? 0
            : Double(noteCount) / maximumNoteSlots
        let restDensity: Double = Double(restStepCount) / Double(steps)
        let multiNoteStepShare: Double = activeStepCount == 0
            ? 0
            : Double(multiNoteStepCount) / Double(activeStepCount)

        _ = calculationStart // placeholder to make timing explicit; no separate measurement emitted

        return MusicalRunDiagnostics(
            imageIdentifier: identifier,
            category: category,
            algorithmVersion: 1,
            rootPitchClass: sequence.harmony.rootPitchClass,
            scale: sequence.harmony.scale.rawValue,
            bpm: sequence.harmony.bpm,
            noteCount: noteCount,
            restStepCount: restStepCount,
            activeStepCount: activeStepCount,
            meanNotesPerActiveStep: meanNotesPerActiveStep,
            singleVoiceStepCount: singleVoiceStepCount,
            twoVoiceStepCount: twoVoiceStepCount,
            threeOrMoreVoiceStepCount: threeOrMoreVoiceStepCount,
            uniqueMIDINotes: uniqueMIDINotes.count,
            uniquePitchClasses: uniquePitchClasses.count,
            pitchClassHistogram: pitchClassHistogram,
            pitchClassEntropy: pitchClassEntropy,
            maximumPitchClassShare: maximumPitchClassShare,
            meanIntervalSemitones: meanInterval,
            maximumJumpSemitones: maxJump,
            melodicTransitionCount: melodicTransitionCount,
            zeroIntervalTransitionCount: zeroIntervals,
            zeroIntervalTransitionShare: zeroIntervalTransitionShare,
            durationHistogram: durationHistogram,
            noteDensity: noteDensity,
            restDensity: restDensity,
            multiNoteStepShare: multiNoteStepShare,
            sequenceGenerationDurationMilliseconds: timings.sequenceGenerationMilliseconds,
            diagnosticsCalculationDurationMilliseconds: 0, // overwritten below
            totalRunDurationMilliseconds: timings.totalRunMilliseconds,
            residentMemoryBytesBefore: memory.before,
            residentMemoryBytesAfter: memory.after
        )
    }

    /// Pre-measured durations for a single run.
    struct Timings: Equatable, Sendable {
        var sequenceGenerationMilliseconds: Double
        var totalRunMilliseconds: Double
    }

    /// Pre-measured resident memory samples. Both are optional because
    /// `MemorySampler.residentBytes()` can return `nil` on some platforms.
    struct Memory: Equatable, Sendable {
        var before: UInt64?
        var after: UInt64?
    }

    // MARK: - Internal helpers

    /// Compute `-Σ p × log2(p)` for `p > 0`. Returns 0 for an empty total.
    static func entropy(from histogram: [Int], total: Int) -> Double {
        guard total > 0 else { return 0 }
        let totalDouble = Double(total)
        var sum = 0.0
        for value in histogram where value > 0 {
            let p = Double(value) / totalDouble
            sum += p * log2(p)
        }
        return -sum
    }

    /// For each step, pick the highest MIDI note (most acute). Rests are
    /// skipped. Notes are read in `PedalSequence.notes` order which is
    /// `(row ascending, step ascending)` from the v1 generator.
    static func mostAcuteIntervals(sequence: PedalSequence, steps: Int) -> [Int] {
        var best: [Int?] = Array(repeating: nil, count: steps)
        for note in sequence.notes {
            guard (0..<steps).contains(note.step) else { continue }
            if let current = best[note.step] {
                if note.midiNote > current { best[note.step] = note.midiNote }
            } else {
                best[note.step] = note.midiNote
            }
        }
        let ordered = best.compactMap { $0 }
        guard ordered.count >= 2 else { return [] }
        var intervals: [Int] = []
        intervals.reserveCapacity(ordered.count - 1)
        for index in 1..<ordered.count {
            intervals.append(abs(ordered[index] - ordered[index - 1]))
        }
        return intervals
    }

    /// Returns `(mean, max)` of the absolute interval values.
    /// Empty input returns `(0, 0)`.
    static func intervalStats(intervals: [Int]) -> (mean: Double, max: Int) {
        guard !intervals.isEmpty else { return (0, 0) }
        let total = intervals.reduce(0, +)
        return (Double(total) / Double(intervals.count), intervals.max() ?? 0)
    }

    /// Histogram of velocities, keyed by a stable string of the velocity
    /// rounded to 4 decimals. The v1 algorithm produces at most 3 distinct
    /// velocities (1/3, 2/3, 1).
    static func durationHistogram(sequence: PedalSequence) -> [String: Int] {
        var histogram: [String: Int] = [:]
        for note in sequence.notes {
            let key = String(format: "%.4f", Double(note.velocity))
            histogram[key, default: 0] += 1
        }
        return histogram
    }

    /// Build a 12-bin histogram of `midiNote % 12` from a flat note list.
    static func pitchClassHistogram(notes: [PedalNote]) -> [Int] {
        var histogram: [Int] = Array(repeating: 0, count: 12)
        for note in notes {
            let pc = ((note.midiNote % 12) + 12) % 12
            histogram[pc] += 1
        }
        return histogram
    }
}
#endif

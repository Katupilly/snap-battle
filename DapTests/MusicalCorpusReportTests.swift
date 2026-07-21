#if DEBUG
import Foundation
import Testing
@testable import Dap

struct MusicalCorpusReportTests {

    @Test func emptyRunsProduceStableEmptyReport() {
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: [],
            corpusIdentifier: "empty",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        #expect(report.corpusSize == 0)
        #expect(report.runs.isEmpty)
        #expect(report.rootHistogram.reduce(0, +) == 0)
        #expect(report.pitchClassHistogram == Array(repeating: 0, count: 12))
        #expect(report.categoryReports.isEmpty)
        #expect(report.meanResidentMemoryDeltaBytes == nil)
        #expect(report.maximumResidentMemoryDeltaBytes == nil)
        #expect(report.minimumResidentMemoryDeltaBytes == nil)
        #expect(report.runsWithMemorySamples == 0)
    }

    @Test func rootAndPitchClassHistogramsAggregateAcrossRuns() {
        let runs = [
            makeRun(identifier: "a", root: 0, pitches: [0, 4, 7]),
            makeRun(identifier: "b", root: 0, pitches: [0, 4, 7]),
            makeRun(identifier: "c", root: 11, pitches: [11, 2, 5])
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "agg",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        #expect(report.rootHistogram[0] == 2)
        #expect(report.rootHistogram[11] == 1)
        #expect(report.rootHistogram.reduce(0, +) == 3)

        #expect(report.pitchClassHistogram[0] == 2)
        #expect(report.pitchClassHistogram[4] == 2)
        #expect(report.pitchClassHistogram[7] == 2)
        #expect(report.pitchClassHistogram[11] == 1)
        #expect(report.pitchClassHistogram[2] == 1)
        #expect(report.pitchClassHistogram[5] == 1)
        #expect(report.pitchClassHistogram.reduce(0, +) == 9)
    }

    @Test func meansIgnoreEmptyRuns() {
        // pitches [0, 4, 7] placed at steps 0, 1, 2 with MIDI 60, 64, 67.
        // Most-acute intervals: |64-60|=4, |67-64|=3. Mean=3.5, max=4.
        let runs = [
            makeRun(identifier: "a", root: 0, pitches: [0, 4, 7], uniquePitches: 3, maxShare: 0.5)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "means",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        #expect(abs(report.meanUniquePitchClassesPerSequence - 3) < 1e-9)
        #expect(abs(report.meanMaximumPitchClassShare - 0.5) < 1e-9)
        #expect(abs(report.meanIntervalSemitones - 3.5) < 1e-9)
        #expect(report.maximumObservedJumpSemitones == 4)
    }

    @Test func voiceShareAndZeroIntervalMeansAggregateAcrossRuns() {
        // Per-run pattern: step 0 holds 3 notes, step 1 holds 2 notes,
        // step 2 holds 1 note. Active = 3, single share = 1/3,
        // two share = 1/3, three share = 1/3. Most-acute per step:
        // step 0 = 64, step 1 = 62, step 2 = 60. Transitions: 2 and 2,
        // so zero share = 0. Mean notes per active step = 6 / 3 = 2.
        let runA = makeRun(
            identifier: "a",
            root: 0,
            notes: noteSpecs(of: [
                (0, 0, 60),
                (0, 1, 62),
                (0, 2, 64),
                (1, 0, 60),
                (1, 1, 62),
                (2, 0, 60)
            ])
        )
        let runB = makeRun(
            identifier: "b",
            root: 0,
            notes: noteSpecs(of: [
                (0, 0, 60),
                (0, 1, 62),
                (0, 2, 64),
                (1, 0, 60),
                (1, 1, 62),
                (2, 0, 60)
            ])
        )
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: [runA, runB],
            corpusIdentifier: "voices",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        #expect(abs(report.meanSingleVoiceStepShare - 1.0 / 3.0) < 1e-9)
        #expect(abs(report.meanTwoVoiceStepShare - 1.0 / 3.0) < 1e-9)
        #expect(abs(report.meanThreeOrMoreVoiceStepShare - 1.0 / 3.0) < 1e-9)
        #expect(abs(report.meanZeroIntervalTransitionShare - 0.0) < 1e-9)
        #expect(abs(report.meanNotesPerActiveStep - 2.0) < 1e-9)
    }

    @Test func categoryRollupsIncludeVoiceAndZeroIntervalMeans() throws {
        let portrait = makeRun(
            identifier: "pd-0",
            root: 0,
            notes: noteSpecs(of: [
                (0, 0, 60),
                (0, 1, 62),
                (0, 2, 64),
                (1, 0, 60),
                (1, 1, 62),
                (2, 0, 60)
            ]),
            category: .portraitDay
        )
        let landscape = makeRun(
            identifier: "ls-0",
            root: 7,
            notes: noteSpecs(of: [(0, 0, 67), (1, 0, 71), (2, 0, 74)]),
            category: .landscapeDay
        )
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: [portrait, landscape],
            corpusIdentifier: "cat",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        let portraitReport = try #require(report.categoryReports.first { $0.category == "portraitDay" })
        #expect(abs(portraitReport.meanSingleVoiceStepShare - 1.0 / 3.0) < 1e-9)
        #expect(abs(portraitReport.meanTwoVoiceStepShare - 1.0 / 3.0) < 1e-9)
        #expect(abs(portraitReport.meanThreeOrMoreVoiceStepShare - 1.0 / 3.0) < 1e-9)
        #expect(abs(portraitReport.meanNotesPerActiveStep - 2.0) < 1e-9)
    }

    @Test func categoryRollupsExcludeOtherCategories() {
        let runs = [
            makeRun(identifier: "pd-0", root: 0, pitches: [0, 4, 7], category: .portraitDay),
            makeRun(identifier: "ls-0", root: 7, pitches: [7, 11, 2], category: .landscapeDay)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "cat",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        #expect(report.categoryCounts["portraitDay"] == 1)
        #expect(report.categoryCounts["landscapeDay"] == 1)
        #expect(report.categoryReports.count == 2)
        let portraitReport = report.categoryReports.first { $0.category == "portraitDay" }
        #expect(portraitReport?.runCount == 1)
        #expect(portraitReport?.rootHistogram[0] == 1)
        let landscapeReport = report.categoryReports.first { $0.category == "landscapeDay" }
        #expect(landscapeReport?.runCount == 1)
        #expect(landscapeReport?.rootHistogram[7] == 1)
    }

    @Test func jsonKeyOrderIsStableAcrossEncodings() throws {
        let runs = [
            makeRun(identifier: "x", root: 0, pitches: [0], scale: "dorian", category: .portraitDay),
            makeRun(identifier: "y", root: 5, pitches: [5], scale: "majorPentatonic", category: .portraitDay)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "sort",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        let json = String(decoding: data, as: UTF8.self)

        // The two scale keys must appear in sorted order in the JSON.
        let dorianIndex = json.range(of: "\"dorian\"")?.lowerBound
        let majorIndex = json.range(of: "\"majorPentatonic\"")?.lowerBound
        #expect(dorianIndex != nil)
        #expect(majorIndex != nil)
        #expect(dorianIndex! < majorIndex!)
    }

    @Test func runsAreSortedByIdentifier() {
        let runs = [
            makeRun(identifier: "c", root: 0, pitches: [0]),
            makeRun(identifier: "a", root: 1, pitches: [1]),
            makeRun(identifier: "b", root: 2, pitches: [2])
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "sortruns",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        #expect(report.runs.map(\.imageIdentifier) == ["a", "b", "c"])
    }

    @Test func normalizedDropsGeneratedAtButPreservesEverythingElse() {
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: [makeRun(identifier: "x", root: 0, pitches: [0])],
            corpusIdentifier: "norm",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        let same = MusicalCorpusReportAggregator.aggregate(
            runs: [makeRun(identifier: "x", root: 0, pitches: [0])],
            corpusIdentifier: "norm",
            generatedAt: "2026-07-22T00:01:00Z"
        )
        #expect(report != same)  // generatedAt differs
        #expect(report.normalized == same.normalized)
    }

    // MARK: - Memory aggregation

    @Test func memoryDeltasAreAggregatedForAllRunsWithSamples() {
        let runs = [
            makeRun(identifier: "a", root: 0, pitches: [0], memoryBefore: 100, memoryAfter: 250),
            makeRun(identifier: "b", root: 0, pitches: [0], memoryBefore: 500, memoryAfter: 600),
            makeRun(identifier: "c", root: 0, pitches: [0], memoryBefore: 800, memoryAfter: 700)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "mem-all",
            generatedAt: ""
        )
        #expect(report.runsWithMemorySamples == 3)
        #expect(report.meanResidentMemoryDeltaBytes == 50) // (150 + 100 - 100) / 3
        #expect(report.maximumResidentMemoryDeltaBytes == 150)
        #expect(report.minimumResidentMemoryDeltaBytes == -100)
    }

    @Test func memoryDeltasIgnoreRunsWithMissingSamples() {
        let runs = [
            makeRun(identifier: "a", root: 0, pitches: [0], memoryBefore: 100, memoryAfter: 200),
            makeRun(identifier: "b", root: 0, pitches: [0], memoryBefore: nil, memoryAfter: 200),
            makeRun(identifier: "c", root: 0, pitches: [0], memoryBefore: 200, memoryAfter: nil),
            makeRun(identifier: "d", root: 0, pitches: [0], memoryBefore: nil, memoryAfter: nil)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "mem-partial",
            generatedAt: ""
        )
        #expect(report.runsWithMemorySamples == 1)
        #expect(report.meanResidentMemoryDeltaBytes == 100)
        #expect(report.maximumResidentMemoryDeltaBytes == 100)
        #expect(report.minimumResidentMemoryDeltaBytes == 100)
    }

    @Test func memoryDeltasAreNilWhenNoRunHasSamples() {
        let runs = [
            makeRun(identifier: "a", root: 0, pitches: [0], memoryBefore: nil, memoryAfter: nil),
            makeRun(identifier: "b", root: 0, pitches: [0], memoryBefore: nil, memoryAfter: nil)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "mem-none",
            generatedAt: ""
        )
        #expect(report.runsWithMemorySamples == 0)
        #expect(report.meanResidentMemoryDeltaBytes == nil)
        #expect(report.maximumResidentMemoryDeltaBytes == nil)
        #expect(report.minimumResidentMemoryDeltaBytes == nil)
    }

    @Test func memoryDeltaCanBeNegative() {
        let runs = [
            makeRun(identifier: "a", root: 0, pitches: [0], memoryBefore: 1_000, memoryAfter: 100)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "mem-negative",
            generatedAt: ""
        )
        #expect(report.runsWithMemorySamples == 1)
        #expect(report.meanResidentMemoryDeltaBytes == -900)
        #expect(report.maximumResidentMemoryDeltaBytes == -900)
        #expect(report.minimumResidentMemoryDeltaBytes == -900)
    }

    // MARK: - Helpers

    private struct NoteSpec: Equatable {
        let step: Int
        let row: Int
        let midi: Int
    }

    private func noteSpecs(of tuples: [(Int, Int, Int)]) -> [NoteSpec] {
        tuples.map { NoteSpec(step: $0.0, row: $0.1, midi: $0.2) }
    }

    private func makeRun(
        identifier: String,
        root: Int,
        notes: [NoteSpec],
        uniquePitches: Int = 1,
        maxShare: Double = 1.0,
        interval: Double = 0,
        scale: String = "majorPentatonic",
        bpm: Int = 100,
        category: CorpusCategory? = nil,
        memoryBefore: UInt64? = nil,
        memoryAfter: UInt64? = nil
    ) -> MusicalRunDiagnostics {
        let pedalNotes = notes.map { spec in
            PedalNote(step: spec.step, row: spec.row, midiNote: spec.midi, velocity: 1)
        }
        let histogram = buildHistogram(pedalNotes)
        let voiceCounts = countVoices(pedalNotes)
        let activeSteps = Set(pedalNotes.map(\.step)).count
        let intervals = mostAcuteIntervals(pedalNotes)
        let zeroCount = intervals.filter { $0 == 0 }.count
        let meanNotes = activeSteps == 0 ? 0.0 : Double(pedalNotes.count) / Double(activeSteps)
        let meanInterval: Double = intervals.isEmpty ? 0 : Double(intervals.reduce(0, +)) / Double(intervals.count)
        let maxJump = intervals.max() ?? 0
        let zeroShare = intervals.isEmpty ? 0.0 : Double(zeroCount) / Double(intervals.count)
        return MusicalRunDiagnostics(
            imageIdentifier: identifier,
            category: category,
            algorithmVersion: 1,
            rootPitchClass: root,
            scale: scale,
            bpm: bpm,
            noteCount: pedalNotes.count,
            restStepCount: 0,
            activeStepCount: activeSteps,
            meanNotesPerActiveStep: meanNotes,
            singleVoiceStepCount: voiceCounts.single,
            twoVoiceStepCount: voiceCounts.two,
            threeOrMoreVoiceStepCount: voiceCounts.threeOrMore,
            uniqueMIDINotes: Set(pedalNotes.map(\.midiNote)).count,
            uniquePitchClasses: Set(pedalNotes.map { ((($0.midiNote % 12) + 12) % 12) }).count,
            pitchClassHistogram: histogram,
            pitchClassEntropy: 0,
            maximumPitchClassShare: maxShare,
            meanIntervalSemitones: meanInterval,
            maximumJumpSemitones: maxJump,
            melodicTransitionCount: intervals.count,
            zeroIntervalTransitionCount: zeroCount,
            zeroIntervalTransitionShare: zeroShare,
            durationHistogram: ["1.0000": pedalNotes.count],
            noteDensity: 0,
            restDensity: 0,
            multiNoteStepShare: activeSteps == 0 ? 0 : Double(voiceCounts.two + voiceCounts.threeOrMore) / Double(activeSteps),
            sequenceGenerationDurationMilliseconds: 0,
            diagnosticsCalculationDurationMilliseconds: 0,
            totalRunDurationMilliseconds: 0,
            residentMemoryBytesBefore: memoryBefore,
            residentMemoryBytesAfter: memoryAfter
        )
        _ = uniquePitches // kept for compatibility with older call sites
    }

    private func makeRun(
        identifier: String,
        root: Int,
        pitches: [Int],
        uniquePitches: Int = 1,
        maxShare: Double = 1.0,
        interval: Double = 0,
        scale: String = "majorPentatonic",
        bpm: Int = 100,
        category: CorpusCategory? = nil,
        memoryBefore: UInt64? = nil,
        memoryAfter: UInt64? = nil
    ) -> MusicalRunDiagnostics {
        let specs = pitches.enumerated().map { index, pc in
            NoteSpec(step: index, row: 0, midi: 60 + pc)
        }
        return makeRun(
            identifier: identifier,
            root: root,
            notes: specs,
            uniquePitches: uniquePitches,
            maxShare: maxShare,
            interval: interval,
            scale: scale,
            bpm: bpm,
            category: category,
            memoryBefore: memoryBefore,
            memoryAfter: memoryAfter
        )
    }

    private func buildHistogram(_ notes: [PedalNote]) -> [Int] {
        var histogram = Array(repeating: 0, count: 12)
        for note in notes {
            let pc = ((note.midiNote % 12) + 12) % 12
            histogram[pc] += 1
        }
        return histogram
    }

    private func countVoices(_ notes: [PedalNote]) -> (single: Int, two: Int, threeOrMore: Int) {
        var perStep: [Int: Int] = [:]
        for note in notes {
            perStep[note.step, default: 0] += 1
        }
        var single = 0, two = 0, threeOrMore = 0
        for count in perStep.values {
            if count == 1 { single += 1 }
            else if count == 2 { two += 1 }
            else if count >= 3 { threeOrMore += 1 }
        }
        return (single, two, threeOrMore)
    }

    private func mostAcuteIntervals(_ notes: [PedalNote]) -> [Int] {
        var bestPerStep: [Int: Int] = [:]
        for note in notes {
            if let current = bestPerStep[note.step] {
                if note.midiNote > current { bestPerStep[note.step] = note.midiNote }
            } else {
                bestPerStep[note.step] = note.midiNote
            }
        }
        let ordered = bestPerStep.keys.sorted().map { bestPerStep[$0]! }
        guard ordered.count >= 2 else { return [] }
        var intervals: [Int] = []
        intervals.reserveCapacity(ordered.count - 1)
        for index in 1..<ordered.count {
            intervals.append(abs(ordered[index] - ordered[index - 1]))
        }
        return intervals
    }
}
#endif

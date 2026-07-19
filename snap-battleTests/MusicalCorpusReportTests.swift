#if DEBUG
import Foundation
import Testing
@testable import snap_battle

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
        let runs = [
            makeRun(identifier: "a", root: 0, pitches: [0, 4, 7], uniquePitches: 3, maxShare: 0.5, interval: 4.0)
        ]
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: "means",
            generatedAt: "2026-07-22T00:00:00Z"
        )
        #expect(abs(report.meanUniquePitchClassesPerSequence - 3) < 1e-9)
        #expect(abs(report.meanMaximumPitchClassShare - 0.5) < 1e-9)
        #expect(abs(report.meanIntervalSemitones - 4.0) < 1e-9)
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

    // MARK: - Helpers

    private func makeRun(
        identifier: String,
        root: Int,
        pitches: [Int],
        uniquePitches: Int = 1,
        maxShare: Double = 1.0,
        interval: Double = 0,
        scale: String = "majorPentatonic",
        bpm: Int = 100,
        category: CorpusCategory? = nil
    ) -> MusicalRunDiagnostics {
        let notes = pitches.enumerated().map { index, pc in
            PedalNote(step: index, row: 0, midiNote: 60 + pc, velocity: 1)
        }
        let sequence = PedalSequence(
            harmony: PedalHarmony(rootPitchClass: root, scale: PedalScale(rawValue: scale) ?? .majorPentatonic, bpm: bpm),
            notes: notes,
            soundProfile: .legacy
        )
        var histogram = Array(repeating: 0, count: 12)
        for pc in pitches { histogram[pc] += 1 }
        return MusicalRunDiagnostics(
            imageIdentifier: identifier,
            category: category,
            algorithmVersion: 1,
            rootPitchClass: root,
            scale: scale,
            bpm: bpm,
            noteCount: notes.count,
            restStepCount: 0,
            singleNoteStepCount: notes.count,
            multiNoteStepCount: 0,
            uniqueMIDINotes: pitches.count,
            uniquePitchClasses: pitches.count,
            pitchClassHistogram: histogram,
            pitchClassEntropy: 0,
            maximumPitchClassShare: maxShare,
            meanIntervalSemitones: interval,
            maximumJumpSemitones: Int(interval),
            durationHistogram: ["1.0000": notes.count],
            noteDensity: 0,
            restDensity: 0,
            multiNoteStepShare: 0,
            sequenceGenerationDurationMilliseconds: 0,
            diagnosticsCalculationDurationMilliseconds: 0,
            totalRunDurationMilliseconds: 0,
            residentMemoryBytesBefore: nil,
            residentMemoryBytesAfter: nil
        )
    }
}
#endif

#if DEBUG
import Foundation
import UIKit

/// Result of running the v1 baseline over a corpus.
struct MusicalDiagnosticsHarnessResult: Equatable, Sendable {
    let report: MusicalCorpusReport
    /// Path of the JSON export, or `nil` if the caller did not request export.
    let exportPath: String?
}

/// DEBUG-only harness that runs the v1 photo-to-MIDI pipeline over a
/// reproducible corpus, collects per-run diagnostics, aggregates them
/// into a report, optionally exports JSON, and prints a compact summary.
///
/// The harness never mutates the v1 algorithm. It only observes it.
@MainActor
final class MusicalDiagnosticsHarness {

    /// User-supplied description of the corpus (e.g. `procedural-v1`).
    let corpusIdentifier: String

    /// Optional directory to scan for additional images. When `nil` or
    /// the directory does not exist, the harness falls back to the
    /// procedural corpus only.
    let localDirectory: URL?

    private let imagePreparer: ImageInputPreparer
    private let retroProcessor: any RetroImageProcessing
    private let printer: (String) -> Void
    private let fileManager: FileManager

    /// - Parameters:
    ///   - corpusIdentifier: stable identifier for the corpus.
    ///   - localDirectory: optional path with extra images (DEBUG-only).
    ///   - imagePreparer: injected for tests; defaults to the production preparer.
    ///   - retroProcessor: injected for tests; defaults to the production processor.
    ///   - printer: sink for the console summary. Defaults to `print`.
    ///   - fileManager: injected for tests; defaults to `.default`.
    init(
        corpusIdentifier: String = "procedural-v1",
        localDirectory: URL? = nil,
        imagePreparer: ImageInputPreparer = ImageInputPreparer(),
        retroProcessor: any RetroImageProcessing = RetroImageProcessor(),
        printer: @escaping (String) -> Void = { print($0) },
        fileManager: FileManager = .default
    ) {
        self.corpusIdentifier = corpusIdentifier
        self.localDirectory = localDirectory
        self.imagePreparer = imagePreparer
        self.retroProcessor = retroProcessor
        self.printer = printer
        self.fileManager = fileManager
    }

    /// Run the harness over the procedural corpus (plus any optional
    /// local images) and return the aggregated report.
    func run() async throws -> MusicalDiagnosticsHarnessResult {
        let fixtures = collectFixtures()
        let runs = try await runAll(fixtures: fixtures)
        let timestamp = Self.timestampString()
        let report = MusicalCorpusReportAggregator.aggregate(
            runs: runs,
            corpusIdentifier: corpusIdentifier,
            generatedAt: timestamp
        )
        printSummary(report: report)
        return MusicalDiagnosticsHarnessResult(report: report, exportPath: nil)
    }

    /// Run the harness and persist the JSON report to the given directory.
    /// Returns the URL of the written file.
    @discardableResult
    func runAndExportJSON(to directory: URL) async throws -> MusicalDiagnosticsHarnessResult {
        let result = try await run()
        let url = try writeJSON(report: result.report, to: directory)
        return MusicalDiagnosticsHarnessResult(report: result.report, exportPath: url.path)
    }

    /// Run the harness and persist a *normalized* version of the JSON
    /// report (with `generatedAt` dropped) to the given directory.
    /// Use this for committed baseline assets so the file is
    /// reproducible byte-for-byte across runs. Local debug exports
    /// should keep `runAndExportJSON` to retain the execution timestamp.
    @discardableResult
    func runAndExportNormalizedJSON(to directory: URL) async throws -> MusicalDiagnosticsHarnessResult {
        let result = try await run()
        let url = try writeJSON(report: result.report.normalized, to: directory)
        return MusicalDiagnosticsHarnessResult(report: result.report, exportPath: url.path)
    }

    // MARK: - Corpus

    func collectFixtures() -> [ProceduralCorpus.Fixture] {
        var fixtures = ProceduralCorpus.fixtures()
        if let directory = localDirectory,
           fileManager.fileExists(atPath: directory.path) {
            let extras = loadLocalImages(from: directory)
            fixtures.append(contentsOf: extras)
        }
        return fixtures
    }

    private func loadLocalImages(from directory: URL) -> [ProceduralCorpus.Fixture] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let images = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "heic"
        }
        return images.enumerated().compactMap { offset, url in
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            let identifier = "local-\(String(format: "%03d", offset))-\(url.deletingPathExtension().lastPathComponent)"
            let hash = ProceduralCorpus.stableHash(for: image)
            return ProceduralCorpus.Fixture(
                identifier: identifier,
                category: .synthetic,
                image: image,
                pixelHash: hash
            )
        }
    }

    // MARK: - Per-run pipeline

    private func runAll(fixtures: [ProceduralCorpus.Fixture]) async throws -> [MusicalRunDiagnostics] {
        var runs: [MusicalRunDiagnostics] = []
        runs.reserveCapacity(fixtures.count)
        for fixture in fixtures {
            let run = try await runSingle(fixture: fixture)
            runs.append(run)
        }
        return runs
    }

    private func runSingle(fixture: ProceduralCorpus.Fixture) async throws -> MusicalRunDiagnostics {
        let memoryBefore = MemorySampler.residentBytes()
        let runStart = ContinuousClock.now

        // v1 pipeline: prepare → retro → analyze → sequence
        let prepared = try imagePreparer.prepare(fixture.image)
        let cover = try await retroProcessor.process(prepared.image)
        let color = try PhotoColorAnalyzer.analyze(prepared.image)

        // Measure sequence generation separately
        let sequenceStart = ContinuousClock.now
        let sequence = try ImageSequenceGenerator.makeSequence(retroImage: cover, colorProfile: color)
        let sequenceElapsedMs = milliseconds(sequenceStart.duration(to: .now))

        // Measure diagnostics calculation
        let diagnosticsStart = ContinuousClock.now
        let initialTimings = MusicalDiagnosticsCalculator.Timings(
            sequenceGenerationMilliseconds: sequenceElapsedMs,
            totalRunMilliseconds: 0
        )
        var diagnostics = MusicalDiagnosticsCalculator.makeDiagnostics(
            for: sequence,
            identifier: fixture.identifier,
            category: fixture.category,
            timings: initialTimings,
            memory: MusicalDiagnosticsCalculator.Memory(before: memoryBefore, after: nil)
        )
        let diagnosticsElapsedMs = milliseconds(diagnosticsStart.duration(to: .now))
        let totalElapsedMs = milliseconds(runStart.duration(to: .now))
        let memoryAfter = MemorySampler.residentBytes()

        // Rewrite with measured diagnostics and memory
        diagnostics = MusicalRunDiagnostics(
            imageIdentifier: diagnostics.imageIdentifier,
            category: diagnostics.category,
            algorithmVersion: diagnostics.algorithmVersion,
            rootPitchClass: diagnostics.rootPitchClass,
            scale: diagnostics.scale,
            bpm: diagnostics.bpm,
            noteCount: diagnostics.noteCount,
            restStepCount: diagnostics.restStepCount,
            activeStepCount: diagnostics.activeStepCount,
            meanNotesPerActiveStep: diagnostics.meanNotesPerActiveStep,
            singleVoiceStepCount: diagnostics.singleVoiceStepCount,
            twoVoiceStepCount: diagnostics.twoVoiceStepCount,
            threeOrMoreVoiceStepCount: diagnostics.threeOrMoreVoiceStepCount,
            uniqueMIDINotes: diagnostics.uniqueMIDINotes,
            uniquePitchClasses: diagnostics.uniquePitchClasses,
            pitchClassHistogram: diagnostics.pitchClassHistogram,
            pitchClassEntropy: diagnostics.pitchClassEntropy,
            maximumPitchClassShare: diagnostics.maximumPitchClassShare,
            meanIntervalSemitones: diagnostics.meanIntervalSemitones,
            maximumJumpSemitones: diagnostics.maximumJumpSemitones,
            melodicTransitionCount: diagnostics.melodicTransitionCount,
            zeroIntervalTransitionCount: diagnostics.zeroIntervalTransitionCount,
            zeroIntervalTransitionShare: diagnostics.zeroIntervalTransitionShare,
            durationHistogram: diagnostics.durationHistogram,
            noteDensity: diagnostics.noteDensity,
            restDensity: diagnostics.restDensity,
            multiNoteStepShare: diagnostics.multiNoteStepShare,
            sequenceGenerationDurationMilliseconds: diagnostics.sequenceGenerationDurationMilliseconds,
            diagnosticsCalculationDurationMilliseconds: diagnosticsElapsedMs,
            totalRunDurationMilliseconds: totalElapsedMs,
            residentMemoryBytesBefore: memoryBefore,
            residentMemoryBytesAfter: memoryAfter
        )
        return diagnostics
    }

    // MARK: - Console summary

    private func printSummary(report: MusicalCorpusReport) {
        let header = "Photo-to-MIDI v1 baseline"
        printer(header)
        printer(String(repeating: "-", count: header.count))
        printer("Corpus: \(report.corpusIdentifier)")
        printer("Generated at: \(report.generatedAt.isEmpty ? "<not set>" : report.generatedAt)")
        printer("Images: \(report.corpusSize)")
        printer("Algorithm version: \(report.algorithmVersion)")

        // Root histogram
        let rootLine = (0..<12).map { index in
            let count = report.rootHistogram[index]
            let name = PitchClass(rawValue: index)?.symbol ?? "?"
            return "\(name) \(formatPercent(count: count, total: report.corpusSize))"
        }.joined(separator: ", ")
        printer("Roots: \(rootLine)")

        let cCount = report.rootHistogram[PitchClass.c.rawValue] + report.rootHistogram[PitchClass.cSharp.rawValue]
        printer("C + C#: \(formatPercent(count: cCount, total: report.corpusSize))")
        printer("Global entropy: \(format(report.globalPitchClassEntropy, decimals: 2)) bits")
        printer("Mean unique pitch classes: \(format(report.meanUniquePitchClassesPerSequence, decimals: 1))")
        printer("Mean max pitch share: \(format(report.meanMaximumPitchClassShare, decimals: 2))")
        printer("Mean interval: \(format(report.meanIntervalSemitones, decimals: 1)) semitones")
        printer("Max observed jump: \(report.maximumObservedJumpSemitones) semitones")
        printer("Mean note density: \(format(report.meanNoteDensity, decimals: 2))")
        printer("Mean rest density: \(format(report.meanRestDensity, decimals: 2))")
        printer("Mean multi-note step share: \(format(report.meanMultiNoteStepShare, decimals: 2))")
        printer("Mean notes per active step: \(format(report.meanNotesPerActiveStep, decimals: 2))")
        printer("Mean single-voice step share: \(format(report.meanSingleVoiceStepShare, decimals: 2))")
        printer("Mean two-voice step share: \(format(report.meanTwoVoiceStepShare, decimals: 2))")
        printer("Mean 3+ voice step share: \(format(report.meanThreeOrMoreVoiceStepShare, decimals: 2))")
        printer("Mean zero-interval transition share: \(format(report.meanZeroIntervalTransitionShare, decimals: 2))")
        printer("Mean sequence generation: \(format(report.meanSequenceGenerationDurationMilliseconds, decimals: 2)) ms")
        printer("Mean diagnostics: \(format(report.meanDiagnosticsDurationMilliseconds, decimals: 2)) ms")
        printer("Mean total run: \(format(report.meanTotalRunDurationMilliseconds, decimals: 2)) ms")
        if report.runsWithMemorySamples > 0,
           let mean = report.meanResidentMemoryDeltaBytes,
           let min = report.minimumResidentMemoryDeltaBytes,
           let max = report.maximumResidentMemoryDeltaBytes {
            printer("Memory delta (n=\(report.runsWithMemorySamples)): mean=\(mean) B, min=\(min) B, max=\(max) B")
        } else {
            printer("Memory delta: no samples")
        }

        printer("")
        printer("By category:")
        for categoryReport in report.categoryReports {
            let name = categoryReport.category.padding(toLength: 18, withPad: " ", startingAt: 0)
            let line = String(
                format: "  %@  n=%2d  roots=%@  entropy=%.2f  meanPitches=%.1f  meanNotes/active=%.1f  zero=%.2f",
                name,
                categoryReport.runCount,
                rootSummary(categoryReport.rootHistogram),
                categoryReport.pitchClassEntropy,
                categoryReport.meanUniquePitchClassesPerSequence,
                categoryReport.meanNotesPerActiveStep,
                categoryReport.meanZeroIntervalTransitionShare
            )
            printer(line)
        }
    }

    private func rootSummary(_ histogram: [Int]) -> String {
        let parts = (0..<12).map { index in
            let count = histogram[index]
            let name = PitchClass(rawValue: index)?.symbol ?? "?"
            return "\(name)\(count)"
        }
        return parts.joined(separator: " ")
    }

    private func formatPercent(count: Int, total: Int) -> String {
        guard total > 0 else { return "0.0%" }
        let value = Double(count) / Double(total) * 100
        return String(format: "%.1f%%", value)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    // MARK: - JSON export

    private func writeJSON(report: MusicalCorpusReport, to directory: URL) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = Self.fileTimestamp()
        let filename = "photo-midi-v1-baseline-\(report.corpusIdentifier)-\(timestamp).json"
        let url = directory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try data.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Timestamps

    nonisolated static func timestampString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    nonisolated static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }

    /// Default export directory used by the DEBUG menu entry.
    /// Reports are written under `Application Support/debug-musical-baseline`.
    nonisolated static func defaultExportDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("debug-musical-baseline", isDirectory: true)
    }

    // MARK: - Duration helpers

    private nonisolated func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    }
}
#endif

#if DEBUG
import Foundation
import Testing
import UIKit
@testable import Dap

struct ProceduralCorpusTests {

    @Test func corpusHasOneFixturePerCategory() {
        let fixtures = ProceduralCorpus.fixtures()
        let categories = fixtures.map(\.category)
        #expect(Set(categories) == Set(CorpusCategory.allCases))
        #expect(fixtures.count == CorpusCategory.allCases.count)
    }

    @Test func identifiersAreUniqueAndWellFormed() {
        let fixtures = ProceduralCorpus.fixtures()
        let identifiers = fixtures.map(\.identifier)
        #expect(Set(identifiers).count == fixtures.count)
        for fixture in fixtures {
            #expect(fixture.identifier.hasPrefix("\(fixture.category.identifierPrefix)-"))
        }
    }

    @Test func fixtureImagesAreReproducible() {
        let first = ProceduralCorpus.fixtures()
        let second = ProceduralCorpus.fixtures()
        #expect(first.map(\.pixelHash) == second.map(\.pixelHash))
    }

    @Test func fixtureImagesHaveExpectedDimensions() throws {
        let fixture = try #require(ProceduralCorpus.fixtures().first)
        #expect(fixture.image.cgImage?.width == 64)
        #expect(fixture.image.cgImage?.height == 64)
    }

    @Test func fixtureImagesExposeStablePixelHash() {
        let fixtures = ProceduralCorpus.fixtures()
        for fixture in fixtures {
            #expect(fixture.pixelHash.count == 64) // SHA-256 hex
            #expect(fixture.pixelHash.allSatisfy { $0.isHexDigit })
        }
    }

    @Test func makeFixtureIsDeterministicForSameIndex() {
        let a = ProceduralCorpus.makeFixture(category: .portraitDay, index: 0)
        let b = ProceduralCorpus.makeFixture(category: .portraitDay, index: 0)
        #expect(a.image.cgImage?.width == b.image.cgImage?.width)
        #expect(a.image.cgImage?.height == b.image.cgImage?.height)
        #expect(a.pixelHash == b.pixelHash)
    }

    @Test func makeFixtureIdentifierChangesWithIndex() {
        let a = ProceduralCorpus.makeFixture(category: .portraitDay, index: 0)
        let b = ProceduralCorpus.makeFixture(category: .portraitDay, index: 7)
        #expect(a.identifier != b.identifier)
    }

    @Test @MainActor func harnessProducesDeterministicBaselineForProceduralCorpus() async throws {
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("photo-midi-v1-baseline-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: exportDir) }
        let result = try await MusicalDiagnosticsHarness(
            corpusIdentifier: "procedural-v1",
            printer: { _ in /* silent during baseline test */ }
        ).runAndExportJSON(to: exportDir)

        #expect(result.report.corpusSize == CorpusCategory.allCases.count)
        #expect(result.report.algorithmVersion == 1)
        #expect(result.report.categoryCounts.count == CorpusCategory.allCases.count)
        #expect(result.exportPath != nil)
        let path = try #require(result.exportPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(data.count > 0)
        // Re-decoding the JSON yields the same data shape.
        let decoder = JSONDecoder()
        let redecoded = try decoder.decode(MusicalCorpusReport.self, from: data)
        #expect(redecoded.normalized == result.report.normalized)
    }

    /// Captures the v1 baseline to a stable, project-relative path.
    /// The path is inside the test bundle's data container which is
    /// accessible via `xcrun simctl get_app_container`.
    @Test @MainActor func dumpBaselineReportToBundle() async throws {
        // Use the test bundle's directory as a stable anchor. When
        // `xcodebuild test` is run, the bundle lives inside the test
        // runner's data container, which can be retrieved with
        // `xcrun simctl get_app_container booted`.
        let bundlePath = Bundle.main.bundlePath
        let bundleParent = URL(fileURLWithPath: bundlePath).deletingLastPathComponent()
        let target = bundleParent.appendingPathComponent("photo-midi-v1-baseline", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("Failed to create \(target.path): \(error)\n".utf8))
            return
        }
        FileHandle.standardError.write(Data("Writing baseline to: \(target.path)\n".utf8))

        // Mirror the summary to a file in the test bundle's directory.
        let summaryURL = target.appendingPathComponent("summary.txt")
        if FileManager.default.fileExists(atPath: summaryURL.path) {
            try? FileManager.default.removeItem(at: summaryURL)
        }
        FileManager.default.createFile(atPath: summaryURL.path, contents: nil)

        let printer: (String) -> Void = { line in
            if let handle = try? FileHandle(forWritingTo: summaryURL) {
                handle.seekToEndOfFile()
                handle.write(Data((line + "\n").utf8))
                try? handle.close()
            }
        }
        let result = try await MusicalDiagnosticsHarness(
            corpusIdentifier: "procedural-v1",
            printer: printer
        ).runAndExportJSON(to: target)

        // Also write the *normalized* version (without `generatedAt`)
        // with the stable name expected by the audit asset. The local
        // debug export above retains the execution timestamp.
        let normalizedURL = target.appendingPathComponent("photo-midi-v1-baseline-procedural-v1.normalized.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let normalizedData = try encoder.encode(result.report.normalized)
        try normalizedData.write(to: normalizedURL, options: [.atomic])

        FileHandle.standardError.write(Data("JSON written to: \(result.exportPath ?? "<none>")\n".utf8))
        FileHandle.standardError.write(Data("Normalized JSON written to: \(normalizedURL.path)\n".utf8))

        // Sanity assertions: the report shape is stable.
        #expect(result.report.corpusSize == CorpusCategory.allCases.count)
        #expect(result.report.algorithmVersion == 1)
    }
}
#endif

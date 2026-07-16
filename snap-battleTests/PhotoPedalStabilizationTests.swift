import AppIntents
import AVFoundation
import Foundation
import Testing
import UIKit
@testable import snap_battle

struct PhotoPedalStabilizationTests {
    @Test func identicalNormalizedInputProducesEqualMusicalData() throws {
        let image = Fixtures.patternImage
        let preparer = ImageInputPreparer()
        let first = try preparer.prepare(image)
        let second = try preparer.prepare(image)
        let firstSequence = try makeSequence(from: first.image)
        let secondSequence = try makeSequence(from: second.image)

        #expect(firstSequence == secondSequence)
        #expect(firstSequence.harmony == secondSequence.harmony)
        #expect(firstSequence.notes == secondSequence.notes)
        #expect(firstSequence.soundProfile == secondSequence.soundProfile)
    }

    @Test func gridLevelsProduceCurrentRestsAndVelocitiesInOrder() throws {
        let sequence = try makeSequence(from: Fixtures.levelPatternImage)

        #expect(sequence.notes.count == 96)
        #expect(sequence.notes[0].step == 1)
        #expect(sequence.notes[0].row == 0)
        #expect(sequence.notes[0].velocity == Float(1.0 / 3.0))
        #expect(sequence.notes[1].step == 2)
        #expect(sequence.notes[1].velocity == Float(2.0 / 3.0))
        #expect(sequence.notes[2].step == 3)
        #expect(sequence.notes[2].velocity == 1)
        #expect(!sequence.notes.contains { $0.step == 0 })
    }

    @Test func sequenceBoundsThresholdsAndSoundProfileRemainCurrent() throws {
        let profiles = [
            PhotoColorProfile(hue: 30, saturation: 0.8, luminance: 0.5, hueVarianceDegrees: 10, edgeDensity: 0.1),
            PhotoColorProfile(hue: 30, saturation: 0.1, luminance: 0.5, hueVarianceDegrees: 30, edgeDensity: 0.1),
            PhotoColorProfile(hue: 30, saturation: 0.1, luminance: 0.5, hueVarianceDegrees: 71, edgeDensity: 0.1)
        ]
        #expect(ImageSequenceGenerator.scale(for: profiles[0]) == .majorPentatonic)
        #expect(ImageSequenceGenerator.scale(for: profiles[1]) == .dorian)
        #expect(ImageSequenceGenerator.scale(for: profiles[2]) == .wholeTone)

        let sequence = try ImageSequenceGenerator.makeSequence(retroImage: Fixtures.levelPatternImage, colorProfile: profiles[0])
        #expect(sequence.notes.allSatisfy { 0 ..< 16 ~= $0.step && 0 ..< 8 ~= $0.row && 0 ... 127 ~= $0.midiNote && 0 ... 1 ~= $0.velocity })
        #expect(70 ... 140 ~= sequence.harmony.bpm)
        #expect([1, 1.5, 2].contains(sequence.soundProfile.octaveRange))
        #expect(0.25 ... 0.98 ~= sequence.soundProfile.gate)
    }

    @Test @MainActor func metadataFailuresUseOnlyTheSpecifiedFallback() async throws {
        let expectedSequence = try await makePipelineSequence(from: Fixtures.patternImage)
        let validOutput = try await PhotoPedalPipeline(
            visionAnalyzer: ObjectDouble(result: .success(Fixtures.observation)),
            generator: MetadataDouble(result: .success(Fixtures.validDraft))
        ).run(image: Fixtures.patternImage) { _ in }
        #expect(validOutput.pedal.name == Fixtures.validDraft.name)
        #expect(validOutput.pedal.description == Fixtures.validDraft.description)

        let failures: [Result<PedalDraft, AppError>] = [
            .failure(.modelUnavailable("unavailable")),
            .failure(.foundationModelRefused("refused")),
            .failure(.foundationModelFailed("failed")),
            .success(PedalDraft(name: "", description: ""))
        ]

        for result in failures {
            let pipeline = PhotoPedalPipeline(generator: MetadataDouble(result: result))
            let output = try await pipeline.run(image: Fixtures.patternImage) { _ in }
            #expect(output.pedal.name == "Photo Pedal")
            #expect(output.pedal.description == "A photo-generated sound pedal.")
            #expect(output.pedal.sequence == expectedSequence)
            #expect(output.cover.cgImage != nil)
        }
    }

    @Test @MainActor func subjectAndVisualAnalysisFailuresDoNotDiscardMusic() async throws {
        let expectedSequence = try await makePipelineSequence(from: Fixtures.patternImage)
        let subjectFailure = PhotoPedalPipeline(
            subjectService: SubjectDouble(result: .failure(.subjectExtractionFailed("test"))),
            visionAnalyzer: ObjectDouble(result: .success(Fixtures.observation)),
            generator: MetadataDouble(result: .success(Fixtures.validDraft))
        )
        let subjectOutput = try await subjectFailure.run(image: Fixtures.patternImage) { _ in }
        #expect(subjectOutput.pedal.sequence == expectedSequence)
        #expect(subjectOutput.pedal.name == Fixtures.validDraft.name)

        let analysisFailure = PhotoPedalPipeline(
            visionAnalyzer: ObjectDouble(result: .failure(.subjectExtractionFailed("test"))),
            generator: MetadataDouble(result: .success(Fixtures.validDraft))
        )
        let analysisOutput = try await analysisFailure.run(image: Fixtures.patternImage) { _ in }
        #expect(analysisOutput.pedal.name == "Photo Pedal")
    }

    @Test @MainActor func preparationAndCoverFailuresRemainErrors() async {
        let pipeline = PhotoPedalPipeline(retroProcessor: StabilizationFailingRetroProcessor())
        do {
            _ = try await pipeline.run(image: Fixtures.patternImage) { _ in }
            Issue.record("Expected cover processing failure")
        } catch {
            // Expected; metadata fallback must not hide cover failures.
        }

        do {
            _ = try await PhotoPedalPipeline().run(image: UIImage()) { _ in }
            Issue.record("Expected image preparation failure")
        } catch {
            // Expected.
        }

        do {
            _ = try PhotoColorAnalyzer.analyze(UIImage())
            Issue.record("Expected color-analysis failure")
        } catch {
            // Expected.
        }

        do {
            _ = try ImageSequenceGenerator.makeSequence(retroImage: UIImage(), colorProfile: Fixtures.colorProfile)
            Issue.record("Expected sequence-generation failure")
        } catch {
            // Expected.
        }
    }

    @Test func latestPedalCanSaveReloadAndReplace() throws {
        removeLatestFiles()
        defer { removeLatestFiles() }

        let first = Fixtures.pedal(name: "First")
        let second = Fixtures.pedal(name: "Second")
        try PedalStore.save(first, cover: Fixtures.cover(.blue))
        let loadedFirst = try #require(PedalStore.loadLatest())
        #expect(loadedFirst.pedal == first)
        #expect(loadedFirst.cover.cgImage?.width == Fixtures.cover(.blue).cgImage?.width)
        #expect(loadedFirst.cover.cgImage?.height == Fixtures.cover(.blue).cgImage?.height)

        try PedalStore.save(second, cover: Fixtures.cover(.orange))
        let loadedSecond = try #require(PedalStore.loadLatest())
        #expect(loadedSecond.pedal == second)
        #expect(loadedSecond.cover.cgImage?.width == Fixtures.cover(.orange).cgImage?.width)
        #expect(loadedSecond.cover.cgImage?.height == Fixtures.cover(.orange).cgImage?.height)
    }

    @Test func incompleteLatestPedalReturnsNil() throws {
        removeLatestFiles()
        defer { removeLatestFiles() }
        try PedalStore.save(Fixtures.pedal(name: "Stored"), cover: Fixtures.cover(.blue))
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.removeItem(at: directory.appendingPathComponent("latest-pedal.png"))
        #expect(PedalStore.loadLatest() == nil)
    }

    @Test @MainActor func synthStopLeavesCleanState() {
        let synth = PhotoPedalSynth()
        synth.stop()
        #expect(!synth.isPlaying)
        synth.stop()
        #expect(!synth.isPlaying)
    }

    @Test @MainActor func appIntentsSetRouterRequests() async throws {
        AppIntentRouter.shared.request = nil
        _ = try await CreatePedalIntent().perform()
        #expect(AppIntentRouter.shared.request == .create)
        _ = try await PlayLastPedalIntent().perform()
        #expect(AppIntentRouter.shared.request == .playLast)
        AppIntentRouter.shared.request = nil
    }

    private func makeSequence(from image: UIImage) throws -> PedalSequence {
        try ImageSequenceGenerator.makeSequence(
            retroImage: image,
            colorProfile: PhotoColorProfile(hue: 120, saturation: 0.8, luminance: 0.5, hueVarianceDegrees: 10, edgeDensity: 0.1)
        )
    }

    private func makePipelineSequence(from image: UIImage) async throws -> PedalSequence {
        let prepared = try ImageInputPreparer().prepare(image)
        let cover = try await RetroImageProcessor().process(prepared.image)
        let color = try PhotoColorAnalyzer.analyze(prepared.image)
        return try ImageSequenceGenerator.makeSequence(retroImage: cover, colorProfile: color)
    }

    private func removeLatestFiles() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        for name in ["latest-pedal.json", "latest-pedal.png"] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

private enum Fixtures {
    static let validDraft = PedalDraft(name: "Blue Hour", description: "A calm blue sound.")
    static let colorProfile = PhotoColorProfile(hue: 120, saturation: 0.8, luminance: 0.5, hueVarianceDegrees: 10, edgeDensity: 0.1)
    static let observation = ObjectObservation(labels: ["bird"], labelConfidence: 0.5, subjectConfidence: nil, aspectRatio: 1, subjectPixelCount: 1, hasTransparency: false, material: .unknown, materialConfidence: 0)

    static var patternImage: UIImage { cover(.blue) }

    static var levelPatternImage: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 8)).image { context in
            for row in 0 ..< 8 {
                for step in 0 ..< 16 {
                    let level = (step % 4)
                    UIColor(white: CGFloat(level) / 4 + 0.01, alpha: 1).setFill()
                    context.cgContext.fill(CGRect(x: step, y: row, width: 1, height: 1))
                }
            }
        }
    }

    static func cover(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 8)).image { context in
            color.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 16, height: 8))
        }
    }

    static func pedal(name: String) -> PhotoPedal {
        let sequence = PedalSequence(
            harmony: PedalHarmony(rootPitchClass: 0, scale: .majorPentatonic, bpm: 100),
            notes: [PedalNote(step: 0, row: 0, midiNote: 60, velocity: 1)],
            soundProfile: .legacy
        )
        return PhotoPedal(id: UUID(), name: name, description: "A test pedal.", sequence: sequence, effect: .reverb, createdAt: Date(timeIntervalSince1970: 1), coverFilename: "latest-pedal.png")
    }
}

private struct MetadataDouble: PedalMetadataGenerating {
    let result: Result<PedalDraft, AppError>
    func generate(observation: ObjectObservation, harmony: PedalHarmony) async throws -> PedalDraft { try result.get() }
}

@MainActor
private struct SubjectDouble: SubjectExtracting {
    let result: Result<ExtractedSubject, AppError>
    let isAvailable = true
    func extract(from image: UIImage) async throws -> ExtractedSubject { try result.get() }
}

@MainActor
private struct ObjectDouble: ObjectAnalyzing {
    let result: Result<ObjectObservation, AppError>
    func analyze(image: UIImage, subject: ExtractedSubject) async throws -> ObjectObservation { try result.get() }
}

private struct StabilizationFailingRetroProcessor: RetroImageProcessing {
    func process(_ image: UIImage) async throws -> UIImage { throw RetroImageProcessorError.invalidImage }
}

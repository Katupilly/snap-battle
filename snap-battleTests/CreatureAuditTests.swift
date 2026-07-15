import Foundation
import Testing
import UIKit
@testable import snap_battle

struct CreatureAuditTests {
    @Test func imageFingerprintIsStableForSamePixels() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
            UIColor.systemOrange.setFill()
            context.cgContext.fill(CGRect(x: 40, y: 0, width: 40, height: 40))
        }
        let source = try #require(image.cgImage)
        let scaledView = UIImage(cgImage: source, scale: 2, orientation: .up)
        let preparer = ImageInputPreparer()

        let first = try preparer.prepare(image)
        let second = try preparer.prepare(scaledView)

        #expect(first.fingerprint == second.fingerprint)
        #expect(first.fingerprint.count == 64)
        #expect(first.processedSize == second.processedSize)
    }

    @Test func sameInputProducesSameStats() {
        let calculator = DeterministicStatCalculator()
        let first = calculator.calculate(name: "Astra", role: .guardian, labels: ["bird", "blue"], material: .unknown)
        let second = calculator.calculate(name: "Astra", role: .guardian, labels: ["bird", "blue"], material: .unknown)
        #expect(first == second)
    }

    @Test func labelOrderDoesNotChangeStats() {
        let calculator = DeterministicStatCalculator()
        let first = calculator.calculate(name: "Astra", role: .guardian, labels: ["bird", "blue"], material: .unknown)
        let second = calculator.calculate(name: "Astra", role: .guardian, labels: ["blue", "bird"], material: .unknown)
        #expect(first == second)
    }

    @Test func totalMatchesBudget() {
        let stats = DeterministicStatCalculator().calculate(name: "Astra", role: .striker, labels: [], material: .unknown)
        #expect(stats.total == CreatureStats.budget)
    }

    @Test func limitsAreRespected() {
        let calculator = DeterministicStatCalculator()
        for role in CreatureRole.allCases {
            let stats = calculator.calculate(name: "Astra", role: role, labels: ["subject"], material: .unknown)
            #expect([stats.defense, stats.power, stats.agility, stats.energy].allSatisfy { CreatureStats.minimum...CreatureStats.maximum ~= $0 })
        }
    }

    @Test func guardianPrioritizesDefense() {
        let stats = DeterministicStatCalculator().calculate(name: "Astra", role: .guardian, labels: [], material: .unknown)
        #expect(stats.defense > stats.power)
        #expect(stats.defense > stats.agility)
        #expect(stats.defense > stats.energy)
    }

    @Test func strikerPrioritizesPower() {
        let stats = DeterministicStatCalculator().calculate(name: "Astra", role: .striker, labels: [], material: .unknown)
        #expect(stats.power > stats.defense)
        #expect(stats.power > stats.agility)
        #expect(stats.power > stats.energy)
    }

    @Test func tricksterPrioritizesAgility() {
        let stats = DeterministicStatCalculator().calculate(name: "Astra", role: .trickster, labels: [], material: .unknown)
        #expect(stats.agility > stats.defense)
        #expect(stats.agility > stats.power)
        #expect(stats.agility > stats.energy)
    }

    @Test func channelerPrioritizesEnergy() {
        let stats = DeterministicStatCalculator().calculate(name: "Astra", role: .channeler, labels: [], material: .unknown)
        #expect(stats.energy > stats.defense)
        #expect(stats.energy > stats.power)
        #expect(stats.energy > stats.agility)
    }

    @Test func materialModifierChangesDistribution() {
        let calculator = DeterministicStatCalculator()
        let unknown = calculator.calculate(name: "Astra", role: .guardian, labels: [], material: .unknown)
        let metallic = calculator.calculate(name: "Astra", role: .guardian, labels: [], material: .metallic)
        #expect(metallic.defense > unknown.defense)
    }

    @Test @MainActor func pipelineCancellationIsPropagated() async {
        let generator = TestGenerator(result: .success(MockDrafts.valid), delay: .seconds(5))
        let pipeline = CreaturePipeline(subjectService: TestSubjectExtractor(), visionAnalyzer: TestObjectAnalyzer(), generator: generator, validator: CreatureDraftValidator(), calculator: DeterministicStatCalculator())
        let task = Task { try await pipeline.run(with: UIImage()) { _ in } }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func invalidAIResponseIsRejected() async {
        let generator = TestGenerator(result: .success(CreatureDraft(name: "", role: "unknown", temperament: "", description: "", tags: [])), delay: .zero)
        let pipeline = CreaturePipeline(subjectService: TestSubjectExtractor(), visionAnalyzer: TestObjectAnalyzer(), generator: generator, validator: CreatureDraftValidator(), calculator: DeterministicStatCalculator())
        do {
            _ = try await pipeline.run(with: TestImages.valid) { _ in }
            Issue.record("Expected invalid draft error")
        } catch let error as AppError {
            #expect(error == .invalidDraft)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func modelUnavailableIsPropagated() async {
        let generator = TestGenerator(result: .failure(.modelUnavailable("deviceNotEligible")), delay: .zero)
        let pipeline = CreaturePipeline(subjectService: TestSubjectExtractor(), visionAnalyzer: TestObjectAnalyzer(), generator: generator, validator: CreatureDraftValidator(), calculator: DeterministicStatCalculator())
        do {
            _ = try await pipeline.run(with: TestImages.valid) { _ in }
            Issue.record("Expected model unavailable error")
        } catch let error as AppError {
            #expect(error == .modelUnavailable("deviceNotEligible"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func retroProcessorUsesDarkestToneForBlack() async throws {
        let output = try await RetroImageProcessor().process(TestImages.solid(.black))
        let outputPixel = try pixel(at: 0, in: output)
        #expect(outputPixel == (20, 24, 20, 255))
    }

    @Test func retroProcessorUsesLightestToneForWhite() async throws {
        let output = try await RetroImageProcessor().process(TestImages.solid(.white))
        let outputPixel = try pixel(at: 0, in: output)
        #expect(outputPixel == (226, 234, 194, 255))
    }

    @Test func retroProcessorUsesFourPaletteColorsAndPreservesTransparency() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 8)).image { context in
            UIColor.clear.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 16, height: 8))
            for column in 0 ..< 4 {
                UIColor(white: CGFloat(column) / 3, alpha: 1).setFill()
                context.cgContext.fill(CGRect(x: column * 4, y: 0, width: 4, height: 4))
            }
        }
        let output = try await RetroImageProcessor().process(image)
        let colors = try pixels(in: output)
        let opaqueColors = Set(colors.filter { $0.3 > 0 }.map { "\($0.0),\($0.1),\($0.2)" })
        #expect(opaqueColors.count <= 4)
        #expect(colors.contains { $0.3 == 0 })
    }

    @Test func retroProcessorPreservesAspectRatioAndIsDeterministic() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            UIColor.gray.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let processor = RetroImageProcessor()
        let first = try await processor.process(image)
        let second = try await processor.process(image)
        #expect(first.size == CGSize(width: 160, height: 80))
        #expect(first.pngData() == second.pngData())
    }

    @Test @MainActor func pipelineFallsBackToExtractedSubjectWhenRetroProcessingFails() async throws {
        let subject = TestImages.valid
        let pipeline = CreaturePipeline(subjectService: TestSubjectExtractor(), visionAnalyzer: TestObjectAnalyzer(), generator: TestGenerator(result: .success(MockDrafts.valid), delay: .zero), validator: CreatureDraftValidator(), calculator: DeterministicStatCalculator(), imagePreparer: ImageInputPreparer(), retroImageProcessor: FailingRetroProcessor())
        let output = try await pipeline.run(with: subject) { _ in }
        let fallbackImage = try #require(UIImage(data: output.creature.extractedSubject))
        let fallbackPixel = try pixel(at: 0, in: fallbackImage)
        #expect(fallbackImage.cgImage?.width == subject.cgImage?.width)
        #expect(fallbackImage.cgImage?.height == subject.cgImage?.height)
        #expect(fallbackPixel == (255, 255, 255, 255))
    }

    @Test @MainActor func pipelineUsesOriginalImageWhenVisionKitFindsNoSubjects() async throws {
        let original = TestImages.solid(.white)
        let retro = RecordingRetroProcessor(delay: .milliseconds(20))
        let pipeline = CreaturePipeline(
            subjectService: NoSubjectExtractor(),
            visionAnalyzer: TestObjectAnalyzer(),
            generator: TestGenerator(result: .success(MockDrafts.valid), delay: .zero),
            validator: CreatureDraftValidator(),
            calculator: DeterministicStatCalculator(),
            imagePreparer: ImageInputPreparer(),
            retroImageProcessor: retro
        )
        var diagnostics: DiagnosticRun?

        let output = try await pipeline.run(with: original) { _ in } progress: { run in
            diagnostics = run
        }

        let processedInput = try #require(retro.lastInput)
        #expect(processedInput.cgImage?.width == original.cgImage?.width)
        #expect(processedInput.cgImage?.height == original.cgImage?.height)
        #expect(try pixel(at: 0, in: processedInput) == pixel(at: 0, in: original))
        #expect(retro.processCount == 1)
        #expect(output.creature.name == MockDrafts.valid.name)
        #expect(output.creature.extractedSubject.isEmpty == false)
        #expect(diagnostics?.subjectLiftingSucceeded == false)
        #expect(diagnostics?.subjectImageSource == "original image")
        #expect(diagnostics?.subjectCount == 0)
        #expect(diagnostics?.retroProcessingDuration != nil)
        #expect(diagnostics?.finalAssemblyDuration != nil)
        let statsDuration = try #require(diagnostics?.durations[.calculatingStats])
        let retroDuration = try #require(diagnostics?.retroProcessingDuration)
        let finalAssemblyDuration = try #require(diagnostics?.finalAssemblyDuration)
        let totalDuration = try #require(diagnostics?.totalDuration)
        print("[Run \(try #require(diagnostics?.id))] Stats completed duration=\(milliseconds(statsDuration))ms")
        print("[Run \(try #require(diagnostics?.id))] Retro processing completed duration=\(milliseconds(retroDuration))ms")
        print("[Run \(try #require(diagnostics?.id))] Final assembly completed duration=\(milliseconds(finalAssemblyDuration))ms")
        print("[Run \(try #require(diagnostics?.id))] Pipeline completed duration=\(milliseconds(totalDuration))ms")
        #expect(statsDuration < retroDuration)
    }

    @Test @MainActor func pipelineDoesNotRequireCameraForUnitTestProcessing() async throws {
        let pipeline = CreaturePipeline(
            subjectService: NoSubjectExtractor(),
            visionAnalyzer: TestObjectAnalyzer(),
            generator: TestGenerator(result: .success(MockDrafts.valid), delay: .zero),
            validator: CreatureDraftValidator(),
            calculator: DeterministicStatCalculator(),
            imagePreparer: ImageInputPreparer(),
            retroImageProcessor: RecordingRetroProcessor()
        )

        let output = try await pipeline.run(with: TestImages.valid) { _ in }

        // The pipeline is fully exercised with service doubles; it never constructs CameraCaptureModel
        // or calls AVCaptureSession/AVCaptureDevice APIs.
        #expect(output.creature.name == MockDrafts.valid.name)
    }

    @Test func retroProcessorAverageDurationIsMeasured() async throws {
        let processor = RetroImageProcessor()
        var durations: [Duration] = []
        for _ in 0 ..< 5 {
            let started = ContinuousClock.now
            _ = try await processor.process(TestImages.solid(.white))
            durations.append(started.duration(to: .now))
        }
        let averageMilliseconds = durations.reduce(0.0) { partial, duration in
            let components = duration.components
            return partial + Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
        } / Double(durations.count)
        print(String(format: "RetroImageProcessor average duration=%.1fms samples=%d", averageMilliseconds, durations.count))
        #expect(averageMilliseconds >= 0)
    }
}

private func pixels(in image: UIImage) throws -> [(UInt8, UInt8, UInt8, UInt8)] {
    guard let cgImage = image.cgImage else { throw RetroImageProcessorError.invalidImage }
    var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
    guard let context = CGContext(data: &bytes, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RetroImageProcessorError.contextCreationFailed }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return stride(from: 0, to: bytes.count, by: 4).map { (bytes[$0], bytes[$0 + 1], bytes[$0 + 2], bytes[$0 + 3]) }
}

private func pixel(at index: Int, in image: UIImage) throws -> (UInt8, UInt8, UInt8, UInt8) {
    try pixels(in: image)[index]
}

private func milliseconds(_ duration: Duration) -> String {
    let components = duration.components
    let value = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    return String(format: "%.1f", value)
}

enum MockDrafts {
    static let valid = CreatureDraft(name: "Astra", role: "guardian", temperament: "calm", description: "A careful guardian.", tags: ["bright"])
}

enum TestImages {
    static var valid: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    static func solid(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            color.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

@MainActor
struct TestSubjectExtractor: SubjectExtracting {
    let isAvailable = true
    func extract(from image: UIImage) async throws -> ExtractedSubject { ExtractedSubject(image: image, confidence: nil, usedFallback: false) }
}

@MainActor
struct NoSubjectExtractor: SubjectExtracting {
    let isAvailable = true
    func extract(from image: UIImage) async throws -> ExtractedSubject {
        ExtractedSubject(
            image: image,
            confidence: nil,
            usedFallback: true,
            fallbackReason: "VisionKit completed without returning an image subject.",
            subjectCount: 0
        )
    }
}

@MainActor
struct TestObjectAnalyzer: ObjectAnalyzing {
    func analyze(image: UIImage, subject: ExtractedSubject) async throws -> ObjectObservation {
        ObjectObservation(labels: ["bird"], labelConfidence: 0.5, subjectConfidence: nil, aspectRatio: 1, subjectPixelCount: 1, hasTransparency: false, material: .unknown, materialConfidence: 0)
    }
}

@MainActor
struct TestGenerator: CreatureGenerating {
    let result: Result<CreatureDraft, AppError>
    let delay: Duration
    let kind: GeneratorKind = .mock
    func availability() -> ModelAvailability {
        ModelAvailability(state: .available, detail: "test", currentLocale: "en_US", currentLocaleSupported: true, supportedLanguages: ["en"])
    }
    func generate(from observation: ObjectObservation) async throws -> CreatureDraft {
        try await Task.sleep(for: delay)
        return try result.get()
    }
}

struct FailingRetroProcessor: RetroImageProcessing {
    func process(_ image: UIImage) async throws -> UIImage { throw RetroImageProcessorError.invalidImage }
}

final class RecordingRetroProcessor: RetroImageProcessing, @unchecked Sendable {
    private let lock = NSLock()
    private let delay: Duration
    private(set) var lastInput: UIImage?
    private(set) var processCount = 0

    init(delay: Duration = .zero) {
        self.delay = delay
    }

    func process(_ image: UIImage) async throws -> UIImage {
        lock.lock()
        lastInput = image
        processCount += 1
        lock.unlock()
        try await Task.sleep(for: delay)
        return try await RetroImageProcessor().process(image)
    }
}

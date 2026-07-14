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

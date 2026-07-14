import Foundation
import OSLog
import UIKit

@MainActor
protocol SubjectExtracting {
    var isAvailable: Bool { get }
    func extract(from image: UIImage) async throws -> ExtractedSubject
}

@MainActor
protocol ObjectAnalyzing {
    func analyze(image: UIImage, subject: ExtractedSubject) async throws -> ObjectObservation
}

@MainActor
final class CreaturePipeline {
    private let subjectService: any SubjectExtracting
    private let visionAnalyzer: any ObjectAnalyzing
    private let generator: any CreatureGenerating
    private let validator: CreatureDraftValidator
    private let calculator: DeterministicStatCalculator
    private let imagePreparer: ImageInputPreparer
    private let retroImageProcessor: any RetroImageProcessing

    init(
        subjectService: any SubjectExtracting,
        visionAnalyzer: any ObjectAnalyzing,
        generator: any CreatureGenerating,
        validator: CreatureDraftValidator,
        calculator: DeterministicStatCalculator,
        imagePreparer: ImageInputPreparer,
        retroImageProcessor: any RetroImageProcessing = RetroImageProcessor()
    ) {
        self.subjectService = subjectService
        self.visionAnalyzer = visionAnalyzer
        self.generator = generator
        self.validator = validator
        self.calculator = calculator
        self.imagePreparer = imagePreparer
        self.retroImageProcessor = retroImageProcessor
    }

    convenience init(subjectService: any SubjectExtracting, visionAnalyzer: any ObjectAnalyzing, generator: any CreatureGenerating, validator: CreatureDraftValidator, calculator: DeterministicStatCalculator) {
        self.init(subjectService: subjectService, visionAnalyzer: visionAnalyzer, generator: generator, validator: validator, calculator: calculator, imagePreparer: ImageInputPreparer())
    }

    convenience init(generator: any CreatureGenerating) {
        self.init(subjectService: SubjectExtractionService(), visionAnalyzer: VisionObjectAnalyzer(), generator: generator, validator: CreatureDraftValidator(), calculator: DeterministicStatCalculator())
    }

    convenience init() {
        self.init(generator: FoundationModelsCreatureGenerator())
    }

    func run(
        with image: UIImage,
        stage: @escaping (ProcessingStage) -> Void,
        progress: @escaping (DiagnosticRun) -> Void = { _ in }
    ) async throws -> PipelineResult {
        let clock = ContinuousClock()
        let totalStarted = clock.now
        var run = DiagnosticRun(id: Self.makeRunID())
        let prepared: PreparedImage
        do {
            try Task.checkCancellation()
            let preparationStarted = clock.now
            prepared = try imagePreparer.prepare(image)
            run.fingerprint = prepared.fingerprint
            run.originalSize = prepared.originalSize
            run.processedSize = prepared.processedSize
            run.approximateMemoryBytes = MemorySampler.residentBytes()
            progress(run)
            debugLog(run.id, "Input prepared", duration: preparationStarted.duration(to: clock.now))
        } catch {
            run.totalDuration = totalStarted.duration(to: clock.now)
            run.approximateMemoryBytes = MemorySampler.residentBytes()
            run.error = Self.fullDescription(error)
            progress(run)
            debugLog(run.id, "Input preparation failed", duration: run.totalDuration, error: Self.logDescription(error))
            throw error
        }
        return try await execute(prepared, run: run, totalStarted: totalStarted, stage: stage, progress: progress)
    }

    func run(
        withPreparedImage prepared: PreparedImage,
        stage: @escaping (ProcessingStage) -> Void,
        progress: @escaping (DiagnosticRun) -> Void = { _ in }
    ) async throws -> PipelineResult {
        let clock = ContinuousClock()
        let totalStarted = clock.now
        var run = DiagnosticRun(id: Self.makeRunID())
        run.fingerprint = prepared.fingerprint
        run.originalSize = prepared.originalSize
        run.processedSize = prepared.processedSize
        run.approximateMemoryBytes = MemorySampler.residentBytes()
        progress(run)
        debugLog(run.id, "Input prepared (reused)", duration: .zero)
        return try await execute(prepared, run: run, totalStarted: totalStarted, stage: stage, progress: progress)
    }

    private func execute(
        _ prepared: PreparedImage,
        run initialRun: DiagnosticRun,
        totalStarted: ContinuousClock.Instant,
        stage: @escaping (ProcessingStage) -> Void,
        progress: @escaping (DiagnosticRun) -> Void
    ) async throws -> PipelineResult {
        var run = initialRun
        let clock = ContinuousClock()
        var activeStage: ProcessingStage?

        do {
            activeStage = .extractingSubject
            stage(.extractingSubject)
            var started = clock.now
            let subject = try await subjectService.extract(from: prepared.image)
            run.durations[.extractingSubject] = started.duration(to: clock.now)
            run.subjectLiftingSucceeded = !subject.usedFallback
            run.subjectImageSource = subject.usedFallback ? "original image" : "extracted subject"
            run.subjectCount = subject.subjectCount
            run.subjectExtractionDetail = subject.fallbackReason
            run.approximateMemoryBytes = MemorySampler.residentBytes()
            progress(run)
            debugLog(run.id, "Subject extraction completed", duration: run.durations[.extractingSubject], error: subject.usedFallback ? "subject lifting fallback; inspect the Debug panel for complete detail" : nil)
            try Task.checkCancellation()

            activeStage = .extractingFeatures
            stage(.extractingFeatures)
            started = clock.now
            let observation = try await visionAnalyzer.analyze(image: prepared.image, subject: subject)
            run.durations[.extractingFeatures] = started.duration(to: clock.now)
            run.observation = observation
            run.approximateMemoryBytes = MemorySampler.residentBytes()
            progress(run)
            debugLog(run.id, "Vision completed", duration: run.durations[.extractingFeatures])
            try Task.checkCancellation()

            activeStage = .generatingCreature
            stage(.generatingCreature)
            started = clock.now
            let rawDraft = try await generator.generate(from: observation)
            let draft = try validator.validate(rawDraft)
            run.durations[.generatingCreature] = started.duration(to: clock.now)
            run.draft = draft
            run.approximateMemoryBytes = MemorySampler.residentBytes()
            progress(run)
            debugLog(run.id, "Foundation Models completed", duration: run.durations[.generatingCreature])
            try Task.checkCancellation()

            activeStage = .calculatingStats
            stage(.calculatingStats)
            started = clock.now
            let role = try role(from: draft)
            let stats = calculator.calculate(name: draft.name, role: role, labels: observation.labels, material: observation.material)
            let presentationImage: UIImage
            do {
                presentationImage = try await retroImageProcessor.process(subject.image)
            } catch {
                presentationImage = subject.image
                debugLog(run.id, "Retro image processing failed; using extracted subject", duration: nil, error: Self.logDescription(error))
            }
            guard let subjectData = presentationImage.pngData() else { throw AppError.imageDecodeFailed }
            let creature = Creature(name: draft.name, role: role, temperament: draft.temperament, description: draft.description, tags: draft.tags, material: observation.material, stats: stats, extractedSubject: subjectData)
            run.durations[.calculatingStats] = started.duration(to: clock.now)
            run.stats = stats
            run.totalDuration = totalStarted.duration(to: clock.now)
            run.approximateMemoryBytes = MemorySampler.residentBytes()
            progress(run)
            debugLog(run.id, "Stats completed", duration: run.durations[.calculatingStats])
            debugLog(run.id, "Pipeline completed", duration: run.totalDuration)
            return PipelineResult(creature: creature, analysis: CreatureAnalysis(observation: observation, draft: draft), durations: run.durations, preparedInput: prepared, diagnostics: run)
        } catch {
            run.failedStage = activeStage
            run.totalDuration = totalStarted.duration(to: clock.now)
            run.approximateMemoryBytes = MemorySampler.residentBytes()
            run.error = Self.fullDescription(error)
            progress(run)
            debugLog(run.id, "Pipeline failed at \(activeStage?.rawValue ?? "unknown stage")", duration: run.totalDuration, error: Self.logDescription(error))
            throw error
        }
    }

    private func role(from draft: CreatureDraft) throws -> CreatureRole {
        guard let role = CreatureRole(rawValue: draft.role) else { throw AppError.invalidDraft }
        return role
    }

    private static func makeRunID() -> String {
        String(format: "%04X", UInt16.random(in: .min ... .max))
    }

    private static func fullDescription(_ error: Error) -> String {
        let type = String(reflecting: type(of: error))
        let nsError = error as NSError
        return "\(type): \(nsError.localizedDescription) [domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)]"
    }

    private static func logDescription(_ error: Error) -> String {
        if let appError = error as? AppError {
            return switch appError {
            case .noSubject: "AppError.noSubject"
            case .subjectExtractionFailed: "AppError.subjectExtractionFailed"
            case .imageDecodeFailed: "AppError.imageDecodeFailed"
            case .invalidDraft: "AppError.invalidDraft"
            case .modelUnavailable: "AppError.modelUnavailable"
            case .foundationModelRefused: "AppError.foundationModelRefused"
            case .foundationModelFailed: "AppError.foundationModelFailed"
            case .cameraUnavailable: "AppError.cameraUnavailable"
            case .cancelled: "AppError.cancelled"
            }
        }
        let nsError = error as NSError
        return "\(String(reflecting: type(of: error))) [domain=\(nsError.domain), code=\(nsError.code)]"
    }

    private func debugLog(_ runID: String, _ message: String, duration: Duration?, error: String? = nil) {
        #if DEBUG
        var fields: [String] = []
        if let duration { fields.append("duration=\(Self.milliseconds(duration))ms") }
        if let error { fields.append("error=\(error)") }
        let suffix = fields.isEmpty ? "" : " " + fields.joined(separator: " ")
        Logger.pipeline.debug("[Run \(runID, privacy: .public)] \(message, privacy: .public)\(suffix, privacy: .public)")
        #endif
    }

    private static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        let milliseconds = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
        return String(format: "%.1f", milliseconds)
    }
}

#if DEBUG
private extension Logger {
    static let pipeline = Logger(subsystem: Bundle.main.bundleIdentifier ?? "snap-battle", category: "Pipeline")
}
#endif

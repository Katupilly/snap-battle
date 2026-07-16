import Foundation
import FoundationModels

struct FoundationModelsPedalGenerator: Sendable, PedalMetadataGenerating {
    func generate(observation: ObjectObservation, harmony: PedalHarmony) async throws -> PedalDraft {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(Locale.current) else { throw AppError.modelUnavailable("O modelo de linguagem no dispositivo não está disponível.") }
        let instructions = """
        You name photo-generated sound pedals from structured visual metadata and musical context.
        You do not see the image. Use only supplied metadata. Return only the requested fields.
        Make the name short, evocative and family-friendly. The description must be exactly one poetic sentence.
        Never mention creature stats, games, combat, or mechanics.
        """
        let prompt = "Create a pedal identity. Visual metadata: \(observation.promptRepresentation). Musical context: root=\(harmony.rootName), scale=\(harmony.scale.rawValue), tempo=\(harmony.bpm) BPM."
        do {
            return try await LanguageModelSession(instructions: instructions).respond(to: prompt, generating: PedalDraft.self).content
        } catch let error as LanguageModelSession.GenerationError {
            if case .refusal = error { throw AppError.foundationModelRefused(error.localizedDescription) }
            throw AppError.foundationModelFailed(error.localizedDescription)
        } catch is CancellationError { throw CancellationError() }
        catch { throw AppError.foundationModelFailed(error.localizedDescription) }
    }
}

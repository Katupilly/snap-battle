import Foundation
import FoundationModels

struct FoundationModelsCreatureGenerator: CreatureGenerating {
    let kind: GeneratorKind = .onDeviceModel

    func availability() -> ModelAvailability {
        let model = SystemLanguageModel.default
        let locale = Locale.current
        let languages = model.supportedLanguages.map { String(describing: $0) }.sorted()
        return switch model.availability {
        case .available:
            ModelAvailability(state: .available, detail: "The on-device system language model is available and ready.", currentLocale: locale.identifier, currentLocaleSupported: model.supportsLocale(locale), supportedLanguages: languages)
        case .unavailable(.deviceNotEligible):
            ModelAvailability(state: .unavailable, detail: "deviceNotEligible: This device does not support Apple Intelligence.", currentLocale: locale.identifier, currentLocaleSupported: model.supportsLocale(locale), supportedLanguages: languages)
        case .unavailable(.appleIntelligenceNotEnabled):
            ModelAvailability(state: .unavailable, detail: "appleIntelligenceNotEnabled: Apple Intelligence is not enabled in Settings on this device.", currentLocale: locale.identifier, currentLocaleSupported: model.supportsLocale(locale), supportedLanguages: languages)
        case .unavailable(.modelNotReady):
            ModelAvailability(state: .notReady, detail: "modelNotReady: The model is still downloading, preparing, or unavailable for another temporary system reason. Downloads are managed by the system and depend on network, battery, and system load.", currentLocale: locale.identifier, currentLocaleSupported: model.supportsLocale(locale), supportedLanguages: languages)
        case .unavailable(let reason):
            ModelAvailability(state: .unavailable, detail: "unavailable: \(String(describing: reason))", currentLocale: locale.identifier, currentLocaleSupported: model.supportsLocale(locale), supportedLanguages: languages)
        }
    }

    func generate(from observation: ObjectObservation) async throws -> CreatureDraft {
        try Task.checkCancellation()
        let availability = availability()
        guard availability.isAvailable else { throw AppError.modelUnavailable(availability.detail) }
        guard availability.currentLocaleSupported else {
            throw AppError.modelUnavailable("unsupportedLocale: The current app locale \(availability.currentLocale) is not supported by the on-device model.")
        }

        let instructions = """
        You create a concise creature concept from structured visual metadata.
        You do not see or interpret an image. Never invent physical facts such as real material, weight, or size.
        Never calculate numeric game attributes, combat values, balance, or stats.
        Use only the supplied metadata. Choose exactly one role: guardian, striker, trickster, or channeler.
        Return only the requested structured fields and keep the text family-friendly.
        """
        let prompt = "Create a creature concept from this structured metadata: \(observation.promptRepresentation)"
        let session = LanguageModelSession(instructions: instructions)
        do {
            return try await session.respond(to: prompt, generating: CreatureDraft.self).content
        } catch let error as LanguageModelSession.GenerationError {
            if case .refusal(_, let context) = error {
                throw AppError.foundationModelRefused("\(fullDescription(error)); context=\(context.debugDescription)")
            }
            throw AppError.foundationModelFailed(fullDescription(error))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AppError.foundationModelFailed(fullDescription(error))
        }
    }

    private func fullDescription(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(String(reflecting: type(of: error))): \(nsError.localizedDescription) [domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)]"
    }
}

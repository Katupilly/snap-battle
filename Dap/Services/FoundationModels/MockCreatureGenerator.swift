import Foundation

#if DEBUG
struct MockCreatureGenerator: CreatureGenerating {
    let kind: GeneratorKind = .mock
    var delay: Duration = .zero
    var draft = CreatureDraft(name: "Debug Moth", role: "trickster", temperament: "curious", description: "A debug-only generated creature.", tags: ["debug", "winged", "curious"])

    func availability() -> ModelAvailability {
        ModelAvailability(state: .available, detail: "Debug mock is active; Foundation Models is bypassed.", currentLocale: Locale.current.identifier, currentLocaleSupported: true, supportedLanguages: ["mock"])
    }

    func generate(from observation: ObjectObservation) async throws -> CreatureDraft {
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
        return draft
    }
}
#endif

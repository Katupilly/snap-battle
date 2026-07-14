import Foundation

@MainActor
protocol CreatureGenerating: Sendable {
    var kind: GeneratorKind { get }
    func availability() -> ModelAvailability
    func generate(from observation: ObjectObservation) async throws -> CreatureDraft
}

struct CreatureDraftValidator: Sendable {
    func validate(_ draft: CreatureDraft) throws -> CreatureDraft {
        let name = normalize(draft.name)
        let role = normalize(draft.role)
        let temperament = normalize(draft.temperament)
        let description = normalize(draft.description)
        let tags = draft.tags.map(normalize).filter { !$0.isEmpty }
        guard !name.isEmpty, name.count <= 32,
              let validRole = CreatureRole(rawValue: role),
              !temperament.isEmpty, temperament.count <= 80,
              !description.isEmpty, description.count <= 180,
              !tags.isEmpty, tags.count <= 3, tags.allSatisfy({ $0.count <= 24 }) else {
            throw AppError.invalidDraft
        }
        return CreatureDraft(name: name, role: validRole.rawValue, temperament: temperament, description: description, tags: tags)
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

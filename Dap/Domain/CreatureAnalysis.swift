import Foundation
import FoundationModels

@Generable(description: "A creature concept from structured visual metadata. Never include numeric game attributes.")
struct CreatureDraft: Sendable, Equatable {
    @Guide(description: "A short memorable creature name") var name: String
    @Guide(description: "One of: guardian, striker, trickster, channeler") var role: String
    @Guide(description: "A short personality descriptor") var temperament: String
    @Guide(description: "A one sentence visual description") var description: String
    @Guide(description: "Three concise visual tags") var tags: [String]
}

struct CreatureAnalysis: Equatable, Sendable {
    let observation: ObjectObservation
    let draft: CreatureDraft
}

import Foundation

struct Creature: Identifiable, Equatable, Sendable {
    let id = UUID()
    let name: String
    let role: CreatureRole
    let temperament: String
    let description: String
    let tags: [String]
    let material: CreatureMaterial
    let stats: CreatureStats
    let extractedSubject: Data
}

struct PipelineResult: Sendable {
    let creature: Creature
    let analysis: CreatureAnalysis
    let durations: [ProcessingStage: Duration]
    let preparedInput: PreparedImage
    let diagnostics: DiagnosticRun
}

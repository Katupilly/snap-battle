import Foundation

enum CreatureRole: String, CaseIterable, Codable, Sendable {
    case guardian, striker, trickster, channeler
}

enum CreatureMaterial: String, CaseIterable, Codable, Sendable {
    case unknown, organic, metallic, aquatic, botanical, stone, textile
}

enum ProcessingStage: String, CaseIterable, Hashable, Sendable {
    case extractingSubject = "Extracting subject"
    case extractingFeatures = "Reading visual features"
    case generatingCreature = "Generating creature"
    case calculatingStats = "Calculating stats + final assembly"
}

enum GeneratorKind: String, Sendable {
    case onDeviceModel = "On-device model"
    case mock = "Mock generator"
}

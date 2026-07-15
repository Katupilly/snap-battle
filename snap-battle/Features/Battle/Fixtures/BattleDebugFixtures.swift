#if DEBUG
import Foundation

enum BattleDebugProfile: String, CaseIterable, Identifiable {
    case balanced
    case power
    case tank

    var id: Self { self }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .power: "Power"
        case .tank: "Tank"
        }
    }

    var creature: Creature {
        switch self {
        case .balanced: Self.balancedCreature
        case .power: Self.powerCreature
        case .tank: Self.tankCreature
        }
    }

    private static let balancedCreature = Creature(
        name: "Balance Bloom",
        role: .trickster,
        temperament: "Even-tempered",
        description: "A stable fixture for testing the complete battle loop.",
        tags: ["debug", "balanced"],
        material: .botanical,
        stats: CreatureStats(defense: 60, power: 60, agility: 60, energy: 60),
        extractedSubject: Data()
    )

    private static let powerCreature = Creature(
        name: "Pulse Fang",
        role: .striker,
        temperament: "Bold",
        description: "A high-power fixture for checking damage and pressure.",
        tags: ["debug", "power"],
        material: .metallic,
        stats: CreatureStats(defense: 35, power: 95, agility: 65, energy: 45),
        extractedSubject: Data()
    )

    private static let tankCreature = Creature(
        name: "Granite Guard",
        role: .guardian,
        temperament: "Patient",
        description: "A durable fixture for checking defense and long matches.",
        tags: ["debug", "tank"],
        material: .stone,
        stats: CreatureStats(defense: 95, power: 40, agility: 40, energy: 65),
        extractedSubject: Data()
    )
}
#endif

import Foundation

enum BattleDemoOpponent {
    static let creature = Creature(
        name: "Volt Moss",
        role: .channeler,
        temperament: "Restless",
        description: "A crackling moss creature that stores static energy.",
        tags: ["demo", "electric", "moss"],
        material: .botanical,
        stats: CreatureStats(defense: 45, power: 60, agility: 55, energy: 80),
        extractedSubject: Data()
    )
}

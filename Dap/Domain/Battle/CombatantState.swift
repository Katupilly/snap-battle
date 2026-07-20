import Foundation

struct CombatantState: Equatable, Sendable {
    let creature: Creature
    let maximumHP: Int
    private(set) var currentHP: Int
    let maximumEnergy: Int
    private(set) var currentEnergy: Int

    init(
        creature: Creature,
        maximumHP: Int,
        currentHP: Int? = nil,
        maximumEnergy: Int,
        currentEnergy: Int? = nil
    ) {
        self.creature = creature
        self.maximumHP = max(1, maximumHP)
        self.currentHP = min(max(currentHP ?? maximumHP, 0), self.maximumHP)
        self.maximumEnergy = max(1, maximumEnergy)
        self.currentEnergy = min(max(currentEnergy ?? maximumEnergy, 0), self.maximumEnergy)
    }

    mutating func spendEnergy(_ amount: Int) {
        currentEnergy = max(0, currentEnergy - max(0, amount))
    }

    mutating func recoverEnergy(_ amount: Int) {
        currentEnergy = min(maximumEnergy, currentEnergy + max(0, amount))
    }

    mutating func receiveDamage(_ amount: Int) {
        currentHP = max(0, currentHP - max(0, amount))
    }
}

import Foundation

struct SimpleBattleAI<Random: RandomNumberProviding>: BattleActionChoosing {
    private var random: Random
    private let balance: BattleBalance

    init(random: Random, balance: BattleBalance = .standard) {
        self.random = random
        self.balance = balance
    }

    mutating func chooseDecision(
        for actor: CombatantState,
        opponent: CombatantState,
        round: Int
    ) -> BattleDecision {
        let validActions = validActions(for: actor)
        let action = chooseAction(validActions: validActions, actor: actor, opponent: opponent)
        return BattleDecision(action: action, timing: chooseTiming())
    }

    private func validActions(for combatant: CombatantState) -> Set<BattleAction> {
        var actions: Set<BattleAction> = [.charge]
        if combatant.currentEnergy >= balance.attackEnergyCost { actions.insert(.attack) }
        if combatant.currentEnergy >= balance.defenseEnergyCost { actions.insert(.defend) }
        return actions
    }

    private mutating func chooseAction(
        validActions: Set<BattleAction>,
        actor: CombatantState,
        opponent: CombatantState
    ) -> BattleAction {
        guard validActions != [.charge] else { return .charge }
        var weights = balance.cpuActionWeights
        if actor.currentHP * 100 <= actor.maximumHP * balance.cpuLowHPThresholdPercent {
            weights[.defend, default: 0] += balance.cpuLowHPDefenseWeightBonus
        }
        if opponent.currentEnergy == 0 {
            weights[.attack, default: 0] += balance.cpuOpponentNoEnergyAttackWeightBonus
        }
        if actor.currentEnergy <= balance.cpuLowEnergyThreshold {
            weights[.charge, default: 0] += balance.cpuLowEnergyChargeWeightBonus
        }
        return weightedChoice(from: BattleAction.allCases.filter { validActions.contains($0) }, weights: weights) ?? .charge
    }

    private mutating func chooseTiming() -> TimingResult {
        weightedChoice(from: TimingResult.allCases, weights: balance.cpuTimingWeights) ?? .good
    }

    private mutating func weightedChoice<Value: Hashable>(from values: [Value], weights: [Value: Int]) -> Value? {
        let total = values.reduce(0) { $0 + max(0, weights[$1] ?? 0) }
        guard total > 0, let fallback = values.first else { return nil }
        let roll = random.nextInt(in: 0..<total)
        var cursor = 0
        for value in values {
            cursor += max(0, weights[value] ?? 0)
            if roll < cursor { return value }
        }
        return fallback
    }
}

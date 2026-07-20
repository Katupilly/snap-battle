import Foundation

protocol BattleActionChoosing {
    mutating func chooseDecision(
        for actor: CombatantState,
        opponent: CombatantState,
        round: Int
    ) -> BattleDecision
}

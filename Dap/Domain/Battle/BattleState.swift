import Foundation

enum BattleOutcome: Equatable, Sendable {
    case playerVictory
    case opponentVictory
    case draw
}

struct BattleState: Equatable, Sendable {
    let player: CombatantState
    let opponent: CombatantState
    let round: Int
    let outcome: BattleOutcome?

    init(player: CombatantState, opponent: CombatantState, round: Int = 1, outcome: BattleOutcome? = nil) {
        self.player = player
        self.opponent = opponent
        self.round = max(1, round)
        self.outcome = outcome
    }
}

import Foundation

struct CombatantRoundResult: Equatable, Sendable {
    let decision: BattleDecision
    let energySpent: Int
    let energyRecovered: Int
    let damageDealt: Int
    let hpBefore: Int
    let hpAfter: Int
    let energyBefore: Int
    let energyAfter: Int
}

struct RoundResult: Equatable, Sendable {
    let round: Int
    let player: CombatantRoundResult
    let opponent: CombatantRoundResult
    let outcome: BattleOutcome?
}

struct BattleRoundResolution: Equatable, Sendable {
    let state: BattleState
    let result: RoundResult
}

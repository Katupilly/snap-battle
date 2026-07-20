import Foundation

struct BattleDecision: Equatable, Codable, Sendable {
    let action: BattleAction
    let timing: TimingResult
}

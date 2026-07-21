import Foundation

struct TimingEvaluator: Sendable {
    let balance: BattleBalance

    init(balance: BattleBalance = .standard) {
        self.balance = balance
    }

    func evaluate(normalizedPosition: Double, agility: Int) -> TimingResult {
        let position = min(1, max(0, normalizedPosition))
        let distanceFromCenter = abs(position - 0.5)
        if distanceFromCenter <= balance.perfectTimingHalfWidth + .ulpOfOne {
            return .perfect
        }
        if distanceFromCenter <= balance.goodTimingHalfWidth(for: agility) + .ulpOfOne {
            return .good
        }
        return .miss
    }
}

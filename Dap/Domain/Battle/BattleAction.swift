import Foundation

enum BattleAction: String, Codable, CaseIterable, Sendable {
    case attack
    case defend
    case charge
}

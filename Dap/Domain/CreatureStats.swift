import Foundation

struct CreatureStats: Equatable, Sendable {
    static let budget = 240
    static let minimum = 20
    static let maximum = 100

    let defense: Int
    let power: Int
    let agility: Int
    let energy: Int

    var total: Int { defense + power + agility + energy }
}

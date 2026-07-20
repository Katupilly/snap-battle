import Foundation

struct DeterministicStatCalculator: Sendable {
    private let seedGenerator = StableSeedGenerator()

    func calculate(name: String, role: CreatureRole, labels: [String], material: CreatureMaterial) -> CreatureStats {
        var weights = weights(for: role)
        apply(material: material, to: &weights)

        let seed = seedGenerator.seed(name: name, role: role, labels: labels, material: material)
        let jitter = [Int(seed % 7), Int((seed / 7) % 7), Int((seed / 49) % 7), Int((seed / 343) % 7)]
        for index in weights.indices { weights[index] += Double(jitter[index]) / 100.0 }

        let remaining = CreatureStats.budget - (CreatureStats.minimum * 4)
        let raw = weights.map { $0 / weights.reduce(0, +) * Double(remaining) }
        var values = raw.map { min(Int($0.rounded(.down)) + CreatureStats.minimum, CreatureStats.maximum) }
        var remainder = CreatureStats.budget - values.reduce(0, +)
        let order = raw.indices.sorted { lhs, rhs in
            let leftFraction = raw[lhs] - floor(raw[lhs])
            let rightFraction = raw[rhs] - floor(raw[rhs])
            return leftFraction == rightFraction ? lhs < rhs : leftFraction > rightFraction
        }
        while remainder > 0 {
            var added = false
            for index in order where values[index] < CreatureStats.maximum && remainder > 0 {
                values[index] += 1
                remainder -= 1
                added = true
            }
            if !added { break }
        }
        return CreatureStats(defense: values[0], power: values[1], agility: values[2], energy: values[3])
    }

    private func weights(for role: CreatureRole) -> [Double] {
        switch role {
        case .guardian: [1.8, 0.8, 0.7, 0.7]
        case .striker: [0.7, 1.8, 0.9, 0.6]
        case .trickster: [0.7, 0.8, 1.8, 0.7]
        case .channeler: [0.7, 0.7, 0.8, 1.8]
        }
    }

    private func apply(material: CreatureMaterial, to weights: inout [Double]) {
        switch material {
        case .metallic: weights[0] += 0.25
        case .stone: weights[0] += 0.20
        case .organic: weights[1] += 0.15
        case .aquatic: weights[3] += 0.15
        case .botanical: weights[3] += 0.10
        case .textile: weights[2] += 0.20
        case .unknown: break
        }
    }
}

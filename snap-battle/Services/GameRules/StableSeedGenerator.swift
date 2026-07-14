import Foundation

struct StableSeedGenerator: Sendable {
    func seed(name: String, role: CreatureRole, labels: [String], material: CreatureMaterial) -> UInt64 {
        let normalizedLabels = labels.map(ObjectObservation.normalize).sorted()
        let canonical = [ObjectObservation.normalize(name), role.rawValue, material.rawValue, normalizedLabels.joined(separator: "|")].joined(separator: "#")
        return canonical.utf8.reduce(UInt64(14695981039346656037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1099511628211
        }
    }
}

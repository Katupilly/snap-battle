import Foundation

nonisolated enum PitchClass: Int, Codable, CaseIterable, Sendable {
    case c = 0
    case cSharp
    case d
    case dSharp
    case e
    case f
    case fSharp
    case g
    case gSharp
    case a
    case aSharp
    case b

    nonisolated static let modulus = 12

    nonisolated static func normalizedRawValue(_ value: Int) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    nonisolated init(normalizing value: Int) {
        self = PitchClass(rawValue: Self.normalizedRawValue(value)) ?? .c
    }

    nonisolated init(midiNote: Int) {
        self.init(normalizing: midiNote)
    }

    nonisolated var symbol: String {
        switch self {
        case .c: "C"
        case .cSharp: "C♯"
        case .d: "D"
        case .dSharp: "D♯"
        case .e: "E"
        case .f: "F"
        case .fSharp: "F♯"
        case .g: "G"
        case .gSharp: "G♯"
        case .a: "A"
        case .aSharp: "A♯"
        case .b: "B"
        }
    }

    nonisolated var localizedName: String {
        switch self {
        case .c: "Dó"
        case .cSharp: "Dó sustenido"
        case .d: "Ré"
        case .dSharp: "Ré sustenido"
        case .e: "Mi"
        case .f: "Fá"
        case .fSharp: "Fá sustenido"
        case .g: "Sol"
        case .gSharp: "Sol sustenido"
        case .a: "Lá"
        case .aSharp: "Lá sustenido"
        case .b: "Si"
        }
    }

    nonisolated var accessibilityName: String {
        "\(localizedName) (\(symbol))"
    }
}

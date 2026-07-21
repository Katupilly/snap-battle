import Foundation

nonisolated struct SRGBColor: Equatable, Sendable, Codable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    nonisolated static let black = SRGBColor(red: 0, green: 0, blue: 0)
    nonisolated static let white = SRGBColor(red: 255, green: 255, blue: 255)

    nonisolated var luminance: Double {
        0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }

    nonisolated func mixed(with color: SRGBColor, ratio: Double) -> SRGBColor {
        let clamped = min(max(ratio, 0), 1)
        return SRGBColor(
            red: Self.mixComponent(red, color.red, ratio: clamped),
            green: Self.mixComponent(green, color.green, ratio: clamped),
            blue: Self.mixComponent(blue, color.blue, ratio: clamped)
        )
    }

    private nonisolated static func mixComponent(_ lhs: UInt8, _ rhs: UInt8, ratio: Double) -> UInt8 {
        let value = Double(lhs) + (Double(rhs) - Double(lhs)) * ratio
        return UInt8(min(255, max(0, Int(value.rounded()))))
    }
}

nonisolated struct PitchColorPalette: Equatable, Sendable, Codable {
    let shadow: SRGBColor
    let dark: SRGBColor
    let base: SRGBColor
    let highlight: SRGBColor

    nonisolated var colors: [SRGBColor] {
        [shadow, dark, base, highlight]
    }
}

nonisolated enum PitchColorIdentity {
    nonisolated static let circleOfFifthsOrder: [PitchClass] = [
        .c, .g, .d, .a, .e, .b, .fSharp, .cSharp, .gSharp, .dSharp, .aSharp, .f
    ]

    // Musical semitones remain chromatic by rawValue (C=0...B=11).
    // This mapping order is perceptual-only (inspired by circle of fifths).
    private nonisolated static let baseByPitchClass: [PitchClass: SRGBColor] = [
        .c: SRGBColor(red: 228, green: 87, blue: 46),
        .g: SRGBColor(red: 217, green: 142, blue: 4),
        .d: SRGBColor(red: 181, green: 161, blue: 0),
        .a: SRGBColor(red: 123, green: 174, blue: 0),
        .e: SRGBColor(red: 45, green: 173, blue: 85),
        .b: SRGBColor(red: 0, green: 169, blue: 154),
        .fSharp: SRGBColor(red: 0, green: 143, blue: 207),
        .cSharp: SRGBColor(red: 45, green: 108, blue: 223),
        .gSharp: SRGBColor(red: 91, green: 86, blue: 214),
        .dSharp: SRGBColor(red: 138, green: 79, blue: 208),
        .aSharp: SRGBColor(red: 179, green: 74, blue: 184),
        .f: SRGBColor(red: 210, green: 74, blue: 136),
    ]

    nonisolated static func baseColor(for pitchClass: PitchClass) -> SRGBColor {
        baseByPitchClass[pitchClass] ?? baseByPitchClass[.c]!
    }

    nonisolated static func tonalPalette(for pitchClass: PitchClass) -> PitchColorPalette {
        tonalPalette(from: baseColor(for: pitchClass))
    }

    nonisolated static func tonalPalette(from base: SRGBColor) -> PitchColorPalette {
        let shadow = base.mixed(with: .black, ratio: 0.72)
        let dark = base.mixed(with: .black, ratio: 0.45)
        let highlight = base.mixed(with: .white, ratio: 0.38)
        return PitchColorPalette(shadow: shadow, dark: dark, base: base, highlight: highlight)
    }
}

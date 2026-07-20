import Foundation
import Testing
@testable import Dap

struct PitchClassDomainTests {
    @Test func chromaticEnumerationRemainsZeroToEleven() {
        #expect(PitchClass.allCases.map(\.rawValue) == Array(0 ... 11))
        #expect(PitchClass.c.rawValue == 0)
        #expect(PitchClass.b.rawValue == 11)
    }

    @Test func midiNormalizationCoversTwoOctaves() {
        let values = Array(48 ..< 72)
        let normalized = values.map { PitchClass(midiNote: $0).rawValue }
        #expect(normalized == Array(repeating: PitchClass.allCases.map(\.rawValue), count: 2).flatMap { $0 })
    }

    @Test func negativeNormalizationDoesNotProduceInvalidIndex() {
        #expect(PitchClass(normalizing: -1) == .b)
        #expect(PitchClass(normalizing: -12) == .c)
        #expect(PitchClass(normalizing: -13) == .b)
        #expect(PitchClass(normalizing: -25) == .b)
    }

    @Test func circleOfFifthsOrderIsPerceptualOnly() {
        #expect(PitchColorIdentity.circleOfFifthsOrder == [.c, .g, .d, .a, .e, .b, .fSharp, .cSharp, .gSharp, .dSharp, .aSharp, .f])
        #expect(PitchClass.c.rawValue == 0)
        #expect(PitchClass.g.rawValue == 7)
        #expect(PitchClass.d.rawValue == 2)
    }

    @Test func colorMappingContainsExactlyTwelveUniqueEntries() {
        let colors = PitchClass.allCases.map { PitchColorIdentity.baseColor(for: $0) }
        #expect(colors.count == 12)
        #expect(Set(colors.map { "\($0.red)-\($0.green)-\($0.blue)" }).count == 12)
    }

    @Test func tonalPalettePreservesAscendingLuminance() {
        for pitch in PitchClass.allCases {
            let palette = PitchColorIdentity.tonalPalette(for: pitch)
            #expect(palette.shadow.luminance < palette.dark.luminance)
            #expect(palette.dark.luminance < palette.base.luminance)
            #expect(palette.base.luminance < palette.highlight.luminance)
        }
    }

    @Test func musicDomainFilesDoNotImportSwiftUIOrUIColor() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let files = [
            repository.appendingPathComponent("Domain/Music/PitchClass.swift"),
            repository.appendingPathComponent("Domain/Music/DominantPitchClassResolver.swift"),
            repository.appendingPathComponent("Domain/Music/PitchColorIdentity.swift"),
        ]
        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            #expect(!contents.contains("import SwiftUI"))
            #expect(!contents.contains("import UIKit"))
            #expect(!contents.contains("UIColor"))
        }
    }
}

#if DEBUG
import Foundation

/// Primary category of a corpus image.
///
/// Each procedural fixture in `ProceduralCorpus` maps to exactly one
/// `CorpusCategory`. The category is used by the report aggregator to
/// compare variety across image archetypes (portraits, landscapes, etc.).
///
/// The list is closed. New categories require a spec update.
enum CorpusCategory: String, Codable, CaseIterable, Sendable, Equatable {
    case portraitDay
    case portraitNight
    case landscapeDay
    case landscapeNight
    case object
    case architecture
    case nature
    case lowSaturation
    case highSaturation
    case bright
    case dark
    case centralSubject
    case noClearSubject
    case synthetic

    /// Stable identifier used as part of `MusicalRunDiagnostics.imageIdentifier`.
    /// The full identifier is `<rawValue>-<fixtureIndex>`.
    var identifierPrefix: String { rawValue }

    /// Human-readable label for console summaries.
    var displayName: String {
        switch self {
        case .portraitDay: "portraitDay"
        case .portraitNight: "portraitNight"
        case .landscapeDay: "landscapeDay"
        case .landscapeNight: "landscapeNight"
        case .object: "object"
        case .architecture: "architecture"
        case .nature: "nature"
        case .lowSaturation: "lowSaturation"
        case .highSaturation: "highSaturation"
        case .bright: "bright"
        case .dark: "dark"
        case .centralSubject: "centralSubject"
        case .noClearSubject: "noClearSubject"
        case .synthetic: "synthetic"
        }
    }
}
#endif

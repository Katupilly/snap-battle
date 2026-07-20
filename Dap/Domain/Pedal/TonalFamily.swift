import Foundation

/// Discrete tonal family classification used by the v2 music generator
/// (`specs/current/photo-midi-variety-v2.md` §7.4 and
/// `specs/current/photo-midi-variety-v2-incremento-2.md` §6.5).
///
/// The v1 algorithm does not classify a tonal family — `TonalFamily` is
/// introduced in the Increment 2 foundation for the v2 root/scale
/// strategy (Increment 3). In Increment 2, every constructed
/// `MusicalProfile` uses `.neutral` as placeholder; the actual
/// classification is added in Increment 3 once the required thresholds
/// are calibrated against the v2 baseline.
///
/// Case order is frozen and `rawValue` is the case name string.
nonisolated enum TonalFamily: String, Sendable, Equatable, Codable, CaseIterable {
    case warm
    case cool
    case green
    case purple
    case neutral
    case lowSaturation
    case highSaturation
}

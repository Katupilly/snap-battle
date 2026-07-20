import Foundation

/// Macro-level shape of a melodic line, as defined in
/// `specs/current/photo-midi-variety-v2.md` §7.3 and
/// `specs/current/photo-midi-variety-v2-incremento-2.md` §6.4.
///
/// The v1 algorithm does not classify contour explicitly; this enum
/// is introduced in the Increment 2 foundation for the v2 compositor
/// (Increment 4) and for `MusicalRunDiagnostics` debug serialization.
/// Case order is frozen and `rawValue` is the case name string —
/// reordering the cases would change persisted DEBUG output.
nonisolated enum MelodicContour: String, Sendable, Equatable, Codable, CaseIterable {
    case ascending
    case descending
    case arched
    case stable
    case meandering
}

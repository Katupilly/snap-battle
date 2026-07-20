import Foundation

/// In-memory snapshot of the deterministic visual descriptors that
/// describe a prepared photo, as defined in
/// `specs/current/photo-midi-variety-v2.md` §7.1 and
/// `specs/current/photo-midi-variety-v2-incremento-2.md` §6.1.
///
/// Increment 2 implements a strict subset of the design. The deferred
/// fields (`isLowSaturation`, `isHighSaturation`, `isBright`, `isDark`,
/// `tonalFamily`, `tonalFamilyWeights`) are added in Increment 3
/// alongside their calibration thresholds. They are intentionally
/// absent from this struct to keep Increment 2 self-contained.
///
/// `VisualAnalysis` is **not persisted**; it is recomputed from
/// `PreparedImage` on demand. The type is `Sendable` and `Equatable`
/// but not `Codable` (no on-disk representation).
struct VisualAnalysis: Sendable, Equatable {
    let colorProfile: PhotoColorProfile
    /// SHA-256 hex of 64 lowercase characters, produced by
    /// `ImageInputPreparer.fingerprint(of:runID:)`.
    let fingerprint: String
    /// 12 bins of 30°, normalized to sum to 1.0 (or 0 when no
    /// `hue` contributed, e.g. fully transparent images).
    let hueHistogram: [Double]
    /// 8 bins of 32 luminance levels (0-31, 32-63, ... 224-255),
    /// normalized to sum to 1.0.
    let luminanceHistogram: [Double]
    /// 4 bins of 0.25 saturation width (0.00-0.25, 0.25-0.50,
    /// 0.50-0.75, 0.75-1.00), normalized to sum to 1.0.
    let saturationHistogram: [Double]
    let meanLuminance: Double
    let meanSaturation: Double
    let luminanceContrast: Double
    let edgeDensity: Double
    let spatialEnergy: SpatialEnergy
    let verticalBalance: Double
    let horizontalBalance: Double
    /// Placeholder, always `0.0` in Increment 2. Subject extraction is
    /// a deferred feature (see design §7.1).
    let subjectPresence: Double
    /// Shannon entropy (bits) of the luminance histogram, capped at
    /// `log2(8) = 3.0`.
    let visualEntropy: Double
}

extension VisualAnalysis {
    /// Four-quadrant mean luminance. Stored as a tuple so the layout is
    /// stable across the codebase. The four components are the means
    /// of luminance for the top-left, top-right, bottom-left and
    /// bottom-right quadrants of the 64×64 sample buffer.
    struct SpatialEnergy: Sendable, Equatable {
        let topLeft: Double
        let topRight: Double
        let bottomLeft: Double
        let bottomRight: Double
    }
}

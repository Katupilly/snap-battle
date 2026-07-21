import Foundation

enum AppError: LocalizedError, Equatable, Sendable {
    case noSubject
    case subjectExtractionFailed(String)
    case imageDecodeFailed
    case invalidDraft
    case modelUnavailable(String)
    case foundationModelRefused(String)
    case foundationModelFailed(String)
    case cameraUnavailable
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noSubject: "No clear subject was found in this image."
        case .subjectExtractionFailed(let message): "Subject extraction failed: \(message)"
        case .imageDecodeFailed: "The selected image could not be decoded."
        case .invalidDraft: "The generated creature did not pass validation."
        case .modelUnavailable(let message): message
        case .foundationModelRefused(let message): "Foundation Models refused the request: \(message)"
        case .foundationModelFailed(let message): "Foundation Models failed: \(message)"
        case .cameraUnavailable: "Camera access is unavailable."
        case .cancelled: "Processing was cancelled."
        }
    }
}

enum ModelReadiness: String, Equatable, Sendable {
    case available
    case unavailable
    case notReady
}

struct ModelAvailability: Equatable, Sendable {
    let state: ModelReadiness
    let detail: String
    let currentLocale: String
    let currentLocaleSupported: Bool
    let supportedLanguages: [String]

    var isAvailable: Bool { state == .available }
}

struct DebugDiagnostics: Equatable, Sendable {
    var modelAvailability = ModelAvailability(state: .unavailable, detail: "Not checked", currentLocale: Locale.current.identifier, currentLocaleSupported: false, supportedLanguages: [])
    var activeGenerator: GeneratorKind = .onDeviceModel
    var cameraAvailable = false
    var subjectExtractionAvailable = false
    var currentRun: DiagnosticRun?
    var firstRun: DiagnosticRun?
    var repeatedRun: DiagnosticRun?
}

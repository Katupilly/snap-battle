import Foundation
import OSLog
import os.signpost

enum PerformanceDiagnostics {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "snap-battle"

    #if DEBUG
    private static let log = OSLog(subsystem: subsystem, category: "Performance")
    private static let logger = Logger(subsystem: subsystem, category: "Performance")
    #endif

    nonisolated static func makeRunID() -> String {
        String(format: "%04X", UInt16.random(in: .min ... .max))
    }

    nonisolated static func measure<T>(
        _ name: StaticString,
        runID: String,
        details: @autoclosure @escaping () -> String = "",
        operation: () throws -> T
    ) rethrows -> T {
        #if DEBUG
        let detailText = details()
        let identifier = OSSignpostID(log: log)
        let started = ContinuousClock.now
        os_signpost(.begin, log: log, name: name, signpostID: identifier)
        defer {
            os_signpost(.end, log: log, name: name, signpostID: identifier)
            logger.debug("run=\(runID, privacy: .public) stage=\(String(describing: name), privacy: .public) durationMs=\(milliseconds(started.duration(to: .now)), privacy: .public) details=\(detailText, privacy: .public)")
        }
        #endif
        return try operation()
    }

    nonisolated static func measure<T>(
        _ name: StaticString,
        runID: String,
        details: @autoclosure @escaping () -> String = "",
        operation: () async throws -> T
    ) async rethrows -> T {
        #if DEBUG
        let detailText = details()
        let identifier = OSSignpostID(log: log)
        let started = ContinuousClock.now
        os_signpost(.begin, log: log, name: name, signpostID: identifier)
        defer {
            os_signpost(.end, log: log, name: name, signpostID: identifier)
            logger.debug("run=\(runID, privacy: .public) stage=\(String(describing: name), privacy: .public) durationMs=\(milliseconds(started.duration(to: .now)), privacy: .public) details=\(detailText, privacy: .public)")
        }
        #endif
        return try await operation()
    }

    nonisolated static func event(_ message: String, runID: String, details: @autoclosure @escaping () -> String = "") {
        #if DEBUG
        logger.debug("run=\(runID, privacy: .public) \(message, privacy: .public) details=\(details(), privacy: .public)")
        #endif
    }

    nonisolated static func signpostEvent(_ name: StaticString, runID: String, details: @autoclosure @escaping () -> String = "") {
        #if DEBUG
        let identifier = OSSignpostID(log: log)
        os_signpost(.event, log: log, name: name, signpostID: identifier)
        logger.debug("run=\(runID, privacy: .public) stage=\(String(describing: name), privacy: .public) details=\(details(), privacy: .public)")
        #endif
    }

    private static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        let value = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
        return String(format: "%.1f", value)
    }
}

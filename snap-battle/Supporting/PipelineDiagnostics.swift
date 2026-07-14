import Darwin
import Foundation

struct PixelSize: Equatable, Sendable {
    let width: Int
    let height: Int

    var description: String { "\(width) × \(height) px" }
}

struct DiagnosticRun: Equatable, Sendable {
    let id: String
    var fingerprint = ""
    var originalSize: PixelSize?
    var processedSize: PixelSize?
    var subjectLiftingSucceeded: Bool?
    var subjectImageSource: String?
    var subjectCount: Int?
    var subjectExtractionDetail: String?
    var observation: ObjectObservation?
    var draft: CreatureDraft?
    var stats: CreatureStats?
    var durations: [ProcessingStage: Duration] = [:]
    var totalDuration: Duration?
    var approximateMemoryBytes: UInt64?
    var failedStage: ProcessingStage?
    var error: String?
}

enum MemorySampler {
    nonisolated static func residentBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : nil
    }
}

import Foundation

enum TimingResult: String, Codable, CaseIterable, Sendable {
    case miss
    case good
    case perfect
}

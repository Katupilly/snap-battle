import Foundation

protocol RandomNumberProviding {
    mutating func nextInt(in range: Range<Int>) -> Int
}

struct SystemRandomNumberProvider: RandomNumberProviding {
    private var generator = SystemRandomNumberGenerator()

    mutating func nextInt(in range: Range<Int>) -> Int {
        Int.random(in: range, using: &generator)
    }
}

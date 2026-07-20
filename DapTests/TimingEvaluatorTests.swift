import Testing
@testable import Dap

struct TimingEvaluatorTests {
    private let evaluator = TimingEvaluator()

    @Test func centerAndPerfectBoundaryArePerfect() {
        #expect(evaluator.evaluate(normalizedPosition: 0.5, agility: 0) == .perfect)
        #expect(evaluator.evaluate(normalizedPosition: 0.54, agility: 100) == .perfect)
    }

    @Test func goodAndMissZonesAreSymmetric() {
        #expect(evaluator.evaluate(normalizedPosition: 0.58, agility: 0) == .good)
        #expect(evaluator.evaluate(normalizedPosition: 0.42, agility: 0) == .good)
        #expect(evaluator.evaluate(normalizedPosition: 0.70, agility: 0) == .miss)
        #expect(evaluator.evaluate(normalizedPosition: 0.30, agility: 0) == .miss)
    }

    @Test func agilityWidensOnlyTheGoodZone() {
        #expect(evaluator.evaluate(normalizedPosition: 0.65, agility: 0) == .miss)
        #expect(evaluator.evaluate(normalizedPosition: 0.65, agility: 100) == .good)
        #expect(evaluator.evaluate(normalizedPosition: 0.53, agility: 0) == .perfect)
        #expect(evaluator.evaluate(normalizedPosition: 0.53, agility: 100) == .perfect)
    }

    @Test func outOfRangePositionsAreClampedAndMiss() {
        #expect(evaluator.evaluate(normalizedPosition: -1, agility: 100) == .miss)
        #expect(evaluator.evaluate(normalizedPosition: 2, agility: 100) == .miss)
    }
}

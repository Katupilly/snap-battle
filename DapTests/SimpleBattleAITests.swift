import Foundation
import Testing
@testable import Dap

struct SimpleBattleAITests {
    @Test func noEnergyAlwaysCharges() {
        var ai = SimpleBattleAI(random: SequenceRandom(values: [0]))
        let decision = ai.chooseDecision(for: combatant(energy: 0), opponent: combatant(), round: 1)

        #expect(decision.action == .charge)
        #expect(TimingResult.allCases.contains(decision.timing))
    }

    @Test func AIOnlyChoosesValidActionsAndDoesNotMutateInputs() {
        var ai = SimpleBattleAI(random: SequenceRandom(values: [0, 0, 0, 0]))
        let actor = combatant(energy: 1)
        let opponent = combatant(energy: 1)
        let initialActor = actor
        let initialOpponent = opponent

        let decision = ai.chooseDecision(for: actor, opponent: opponent, round: 1)

        #expect([BattleAction.attack, .defend, .charge].contains(decision.action))
        #expect(actor == initialActor)
        #expect(opponent == initialOpponent)
    }

    @Test func controlledRandomnessAppliesContextualActionWeights() {
        var lowHealthAI = SimpleBattleAI(random: SequenceRandom(values: [50, 0]))
        var exposedOpponentAI = SimpleBattleAI(random: SequenceRandom(values: [0, 0]))
        var lowEnergyAI = SimpleBattleAI(random: SequenceRandom(values: [100, 0]))

        let lowHealth = combatant(hp: 30, energy: 3)
        let healthy = combatant(hp: 100, energy: 3)
        let lowEnergy = combatant(hp: 100, energy: 1)

        #expect(lowHealthAI.chooseDecision(for: lowHealth, opponent: healthy, round: 1).action == .defend)
        #expect(exposedOpponentAI.chooseDecision(for: healthy, opponent: combatant(energy: 0), round: 1).action == .attack)
        #expect(lowEnergyAI.chooseDecision(for: lowEnergy, opponent: healthy, round: 1).action == .charge)
    }

    @Test func injectedRandomSequenceIsDeterministic() {
        var first = SimpleBattleAI(random: SequenceRandom(values: [44, 79]))
        var second = SimpleBattleAI(random: SequenceRandom(values: [44, 79]))
        let actor = combatant()
        let opponent = combatant()

        #expect(first.chooseDecision(for: actor, opponent: opponent, round: 1) == second.chooseDecision(for: actor, opponent: opponent, round: 1))
    }

    private func combatant(hp: Int = 100, energy: Int = 3) -> CombatantState {
        CombatantState(creature: creature(), maximumHP: 100, currentHP: hp, maximumEnergy: 6, currentEnergy: energy)
    }

    private func creature() -> Creature {
        Creature(name: "AI", role: .striker, temperament: "Focused", description: "Fixture", tags: [], material: .unknown, stats: CreatureStats(defense: 20, power: 20, agility: 20, energy: 20), extractedSubject: Data())
    }
}

private struct SequenceRandom: RandomNumberProviding {
    private var values: [Int]
    private var index = 0

    init(values: [Int]) {
        self.values = values
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let value = values[index % values.count]
        index += 1
        return range.lowerBound + value % range.count
    }
}

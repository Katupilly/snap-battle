import Foundation
import Testing
@testable import Dap

@MainActor
struct BattleViewModelTests {
    @Test func startsChoosingAnActionWithFullCombatants() {
        let model = makeModel()

        #expect(model.phase == .choosingAction)
        #expect(model.state.round == 1)
        #expect(model.state.player.currentHP == model.state.player.maximumHP)
        #expect(model.state.player.currentEnergy == model.state.player.maximumEnergy)
        #expect(model.roundResult == nil)
    }

    @Test func validActionStartsTimingAndSecondActionIsIgnored() {
        let model = makeModel()

        model.chooseAction(.attack)
        #expect(model.phase == .timing(.attack))

        model.chooseAction(.charge)
        #expect(model.phase == .timing(.attack))
    }

    @Test func unavailableActionDoesNotStartTiming() {
        let chooser = CountingChooser()
        let model = makeModel(chooser: chooser)

        for _ in 0..<3 {
            model.chooseAction(.attack)
            model.confirmTiming(normalizedPosition: 0.5)
            model.continueBattle()
        }

        #expect(model.state.player.currentEnergy == 0)
        #expect(model.phase == .choosingAction)
        model.chooseAction(.attack)
        #expect(model.phase == .choosingAction)
    }

    @Test func timingResolvesExactlyOneRoundAndConsultsCPUOnce() {
        let chooser = CountingChooser()
        let model = makeModel(chooser: chooser)

        model.chooseAction(.attack)
        model.confirmTiming(normalizedPosition: 0.5)

        #expect(chooser.callCount == 1)
        #expect(model.state.round == 2)
        #expect(model.roundResult?.player.decision.timing == .perfect)
        #expect(model.phase == .showingRoundResult)

        model.confirmTiming(normalizedPosition: 0.5)
        #expect(chooser.callCount == 1)
        #expect(model.state.round == 2)
    }

    @Test func completedRoundBlocksActionsUntilContinued() {
        let model = makeModel()
        model.chooseAction(.charge)
        model.confirmTiming(normalizedPosition: 0.5)
        let result = model.roundResult

        model.chooseAction(.attack)
        #expect(model.phase == .showingRoundResult)
        #expect(model.roundResult == result)

        model.continueBattle()
        #expect(model.phase == .choosingAction)
        #expect(model.roundResult == nil)
        #expect(model.state.round == 2)
    }

    @Test func outcomeFinishesBattleAndRestartRestoresInitialState() {
        let opponent = creature(name: "Fragile", defense: 0, power: 20, energy: 20)
        let player = creature(name: "Strong", defense: 30, power: 1_000, energy: 80)
        let model = BattleViewModel(player: player, opponent: opponent, opponentChooser: CountingChooser())

        model.chooseAction(.attack)
        model.confirmTiming(normalizedPosition: 0.5)

        #expect(model.phase == .finished(.playerVictory))
        #expect(model.roundResult?.outcome == .playerVictory)
        model.restart()

        #expect(model.phase == .choosingAction)
        #expect(model.state.round == 1)
        #expect(model.state.outcome == nil)
        #expect(model.state.player.currentHP == model.state.player.maximumHP)
        #expect(model.state.player.currentEnergy == model.state.player.maximumEnergy)
        #expect(model.roundResult == nil)
    }

    private func makeModel(chooser: CountingChooser? = nil) -> BattleViewModel {
        BattleViewModel(player: creature(name: "Player", defense: 30, power: 40, energy: 30), opponent: creature(name: "Opponent", defense: 30, power: 40, energy: 30), opponentChooser: chooser ?? CountingChooser())
    }

    private func creature(name: String, defense: Int, power: Int, energy: Int) -> Creature {
        Creature(name: name, role: .striker, temperament: "Focused", description: "Fixture", tags: [], material: .unknown, stats: CreatureStats(defense: defense, power: power, agility: 40, energy: energy), extractedSubject: Data())
    }
}

@MainActor
private final class CountingChooser: BattleActionChoosing {
    private(set) var callCount = 0

    func chooseDecision(for actor: CombatantState, opponent: CombatantState, round: Int) -> BattleDecision {
        callCount += 1
        return BattleDecision(action: .charge, timing: .good)
    }
}

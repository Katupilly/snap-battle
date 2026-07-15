import Foundation
import Testing
@testable import snap_battle

struct BattleEngineTests {
    private let engine = BattleEngine()

    @Test func initializesHPAndEnergyFromCreatureStats() {
        let player = creature(defense: 42, energy: 50)
        let state = engine.makeInitialState(player: player, opponent: creature())

        #expect(state.player.maximumHP == 122)
        #expect(state.player.currentHP == 122)
        #expect(state.player.maximumEnergy == 4)
        #expect(state.player.currentEnergy == 4)
    }

    @Test func energyUsesConfiguredMinimumAndMaximum() {
        let low = engine.makeInitialState(player: creature(energy: 0), opponent: creature()).player
        let high = engine.makeInitialState(player: creature(energy: 100), opponent: creature()).player

        #expect(low.maximumEnergy == 3)
        #expect(high.maximumEnergy == 6)
    }

    @Test func attackAndDefenseConsumeEnergyWhileChargeDoesNot() throws {
        let state = engine.makeInitialState(player: creature(), opponent: creature())

        let attack = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.charge))
        let defense = try engine.resolveRound(state: state, playerDecision: decision(.defend), opponentDecision: decision(.charge))
        let charge = try engine.resolveRound(state: state, playerDecision: decision(.charge), opponentDecision: decision(.defend))

        #expect(attack.result.player.energySpent == 1)
        #expect(defense.result.player.energySpent == 1)
        #expect(charge.result.player.energySpent == 0)
    }

    @Test func chargeRecoveryMatchesTimingAndRespectsMaximum() throws {
        let state = customState(playerEnergy: 0, opponentEnergy: 0)
        let miss = try engine.resolveRound(state: state, playerDecision: decision(.charge, .miss), opponentDecision: decision(.charge, .miss))
        let good = try engine.resolveRound(state: state, playerDecision: decision(.charge, .good), opponentDecision: decision(.charge, .good))
        let perfect = try engine.resolveRound(state: state, playerDecision: decision(.charge, .perfect), opponentDecision: decision(.charge, .perfect))
        let almostFull = customState(playerEnergy: 5, opponentEnergy: 5)
        let capped = try engine.resolveRound(state: almostFull, playerDecision: decision(.charge, .perfect), opponentDecision: decision(.charge, .perfect))

        #expect(miss.state.player.currentEnergy == 1)
        #expect(good.state.player.currentEnergy == 2)
        #expect(perfect.state.player.currentEnergy == 3)
        #expect(capped.state.player.currentEnergy == capped.state.player.maximumEnergy)
        #expect(capped.state.opponent.currentEnergy == capped.state.opponent.maximumEnergy)
    }

    @Test func rejectsInvalidActionsWithoutChangingInputState() {
        let state = customState(playerEnergy: 0, opponentEnergy: 3)
        let expectedState = state
        do {
            _ = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.charge))
            Issue.record("Expected invalid player attack")
        } catch let error as BattleEngineError {
            #expect(error == .invalidPlayerAction(.attack))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(state == expectedState)
    }

    @Test func rejectsDefenseWithoutEnergy() {
        let state = customState(playerEnergy: 0, opponentEnergy: 3)
        do {
            _ = try engine.resolveRound(state: state, playerDecision: decision(.defend), opponentDecision: decision(.charge))
            Issue.record("Expected invalid player defense")
        } catch let error as BattleEngineError {
            #expect(error == .invalidPlayerAction(.defend))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func attackCombinationsResolveSimultaneouslyAndByDefenseState() throws {
        let state = engine.makeInitialState(player: creature(power: 100), opponent: creature(defense: 100, power: 100))
        let attackVsAttack = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.attack))
        let attackVsDefense = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.defend, .perfect))
        let attackVsCharge = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.charge))

        #expect(attackVsAttack.result.player.damageDealt > 0)
        #expect(attackVsAttack.result.opponent.damageDealt > 0)
        #expect(attackVsDefense.result.player.damageDealt < attackVsCharge.result.player.damageDealt)
        #expect(attackVsCharge.result.player.damageDealt == engine.balance.attackDamage(for: state.player.creature, timing: .good))
    }

    @Test func defenseAndChargeAgainstAttackApplyTheExpectedOpponentDamage() throws {
        let state = engine.makeInitialState(player: creature(defense: 100), opponent: creature(power: 100))
        let defending = try engine.resolveRound(state: state, playerDecision: decision(.defend, .perfect), opponentDecision: decision(.attack))
        let charging = try engine.resolveRound(state: state, playerDecision: decision(.charge), opponentDecision: decision(.attack))

        #expect(defending.result.opponent.damageDealt < charging.result.opponent.damageDealt)
        #expect(charging.result.opponent.damageDealt == engine.balance.attackDamage(for: state.opponent.creature, timing: .good))
    }

    @Test func nonAttackingCombinationsOnlyApplyCostsAndChargeRecovery() throws {
        let state = customState(playerEnergy: 1, opponentEnergy: 1)
        let defenseVsDefense = try engine.resolveRound(state: state, playerDecision: decision(.defend), opponentDecision: decision(.defend))
        let defenseVsCharge = try engine.resolveRound(state: state, playerDecision: decision(.defend), opponentDecision: decision(.charge, .perfect))
        let chargeVsDefense = try engine.resolveRound(state: state, playerDecision: decision(.charge, .perfect), opponentDecision: decision(.defend))
        let chargeVsCharge = try engine.resolveRound(state: state, playerDecision: decision(.charge, .good), opponentDecision: decision(.charge, .perfect))

        #expect(defenseVsDefense.result.player.damageDealt == 0)
        #expect(defenseVsDefense.result.opponent.damageDealt == 0)
        #expect(defenseVsCharge.result.player.energySpent == 1)
        #expect(defenseVsCharge.result.opponent.energyRecovered == 3)
        #expect(chargeVsDefense.result.player.energyRecovered == 3)
        #expect(chargeVsDefense.result.opponent.energySpent == 1)
        #expect(chargeVsCharge.result.player.energyRecovered == 2)
        #expect(chargeVsCharge.result.opponent.energyRecovered == 3)
    }

    @Test func timingChangesAttackDamageAndDefenseReduction() throws {
        let state = engine.makeInitialState(player: creature(power: 100), opponent: creature(defense: 100))
        let missedAttack = try engine.resolveRound(state: state, playerDecision: decision(.attack, .miss), opponentDecision: decision(.charge))
        let goodAttack = try engine.resolveRound(state: state, playerDecision: decision(.attack, .good), opponentDecision: decision(.charge))
        let perfectAttack = try engine.resolveRound(state: state, playerDecision: decision(.attack, .perfect), opponentDecision: decision(.charge))
        let weakDefense = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.defend, .miss))
        let normalDefense = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.defend, .good))
        let strongDefense = try engine.resolveRound(state: state, playerDecision: decision(.attack), opponentDecision: decision(.defend, .perfect))

        #expect(missedAttack.result.player.damageDealt < goodAttack.result.player.damageDealt)
        #expect(goodAttack.result.player.damageDealt < perfectAttack.result.player.damageDealt)
        #expect(strongDefense.result.player.damageDealt < normalDefense.result.player.damageDealt)
        #expect(normalDefense.result.player.damageDealt < weakDefense.result.player.damageDealt)
    }

    @Test func HPAndEnergyAreClampedAndOutcomeHandlesVictoryDefeatAndDraw() throws {
        let playerWins = customState(playerHP: 100, opponentHP: 1)
        let opponentWins = customState(playerHP: 1, opponentHP: 100)
        let draw = customState(playerHP: 1, opponentHP: 1)
        let lowEnergy = customState(playerEnergy: 1, opponentEnergy: 1)

        let victory = try engine.resolveRound(state: playerWins, playerDecision: decision(.attack), opponentDecision: decision(.charge))
        let defeat = try engine.resolveRound(state: opponentWins, playerDecision: decision(.charge), opponentDecision: decision(.attack))
        let tie = try engine.resolveRound(state: draw, playerDecision: decision(.attack), opponentDecision: decision(.attack))
        let exhausted = try engine.resolveRound(state: lowEnergy, playerDecision: decision(.attack), opponentDecision: decision(.defend))

        #expect(victory.state.opponent.currentHP == 0)
        #expect(victory.state.outcome == .playerVictory)
        #expect(defeat.state.outcome == .opponentVictory)
        #expect(tie.state.player.currentHP == 0)
        #expect(tie.state.opponent.currentHP == 0)
        #expect(tie.state.outcome == .draw)
        #expect(exhausted.state.player.currentEnergy == 0)
        #expect(exhausted.state.opponent.currentEnergy == 0)
        #expect(exhausted.state.player.currentEnergy <= exhausted.state.player.maximumEnergy)
        #expect(exhausted.state.opponent.currentEnergy <= exhausted.state.opponent.maximumEnergy)
    }

    @Test func finishedBattleRejectsFurtherRoundsAndRoundResultTracksState() throws {
        let initial = customState(playerHP: 100, opponentHP: 1)
        let resolution = try engine.resolveRound(state: initial, playerDecision: decision(.attack), opponentDecision: decision(.charge))

        #expect(resolution.state.round == 2)
        #expect(resolution.result.round == 1)
        #expect(resolution.result.player.hpBefore == 100)
        #expect(resolution.result.player.hpAfter == resolution.state.player.currentHP)
        #expect(resolution.result.opponent.hpBefore == 1)
        #expect(resolution.result.opponent.hpAfter == resolution.state.opponent.currentHP)
        #expect(resolution.result.player.energyBefore == 3)
        #expect(resolution.result.player.energyAfter == resolution.state.player.currentEnergy)
        #expect(resolution.result.opponent.energyBefore == 3)
        #expect(resolution.result.opponent.energyAfter == resolution.state.opponent.currentEnergy)

        do {
            _ = try engine.resolveRound(state: resolution.state, playerDecision: decision(.charge), opponentDecision: decision(.charge))
            Issue.record("Expected completed battle rejection")
        } catch let error as BattleEngineError {
            #expect(error == .battleAlreadyFinished)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func decision(_ action: BattleAction, _ timing: TimingResult = .good) -> BattleDecision {
        BattleDecision(action: action, timing: timing)
    }

    private func customState(playerHP: Int = 100, opponentHP: Int = 100, playerEnergy: Int = 3, opponentEnergy: Int = 3) -> BattleState {
        BattleState(
            player: CombatantState(creature: creature(), maximumHP: 100, currentHP: playerHP, maximumEnergy: 6, currentEnergy: playerEnergy),
            opponent: CombatantState(creature: creature(), maximumHP: 100, currentHP: opponentHP, maximumEnergy: 6, currentEnergy: opponentEnergy)
        )
    }

    private func creature(defense: Int = 20, power: Int = 20, agility: Int = 20, energy: Int = 20) -> Creature {
        Creature(name: "Test", role: .guardian, temperament: "Calm", description: "Fixture", tags: [], material: .unknown, stats: CreatureStats(defense: defense, power: power, agility: agility, energy: energy), extractedSubject: Data())
    }
}

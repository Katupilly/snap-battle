import Foundation

enum BattleEngineError: Error, Equatable, Sendable {
    case battleAlreadyFinished
    case invalidPlayerAction(BattleAction)
    case invalidOpponentAction(BattleAction)
}

struct BattleEngine: Sendable {
    let balance: BattleBalance

    init(balance: BattleBalance = .standard) {
        self.balance = balance
    }

    func makeInitialState(player: Creature, opponent: Creature) -> BattleState {
        BattleState(
            player: makeCombatantState(for: player),
            opponent: makeCombatantState(for: opponent)
        )
    }

    func validActions(for combatant: CombatantState) -> Set<BattleAction> {
        var actions: Set<BattleAction> = [.charge]
        if combatant.currentEnergy >= balance.attackEnergyCost { actions.insert(.attack) }
        if combatant.currentEnergy >= balance.defenseEnergyCost { actions.insert(.defend) }
        return actions
    }

    func resolveRound(
        state: BattleState,
        playerDecision: BattleDecision,
        opponentDecision: BattleDecision
    ) throws -> BattleRoundResolution {
        guard state.outcome == nil else { throw BattleEngineError.battleAlreadyFinished }
        guard validActions(for: state.player).contains(playerDecision.action) else {
            throw BattleEngineError.invalidPlayerAction(playerDecision.action)
        }
        guard validActions(for: state.opponent).contains(opponentDecision.action) else {
            throw BattleEngineError.invalidOpponentAction(opponentDecision.action)
        }

        var player = state.player
        var opponent = state.opponent
        let playerHPBefore = player.currentHP
        let opponentHPBefore = opponent.currentHP
        let playerEnergyBefore = player.currentEnergy
        let opponentEnergyBefore = opponent.currentEnergy

        let playerEnergySpent = energyCost(for: playerDecision.action)
        let opponentEnergySpent = energyCost(for: opponentDecision.action)
        player.spendEnergy(playerEnergySpent)
        opponent.spendEnergy(opponentEnergySpent)

        let playerDamage = damage(
            attacker: state.player,
            attackerDecision: playerDecision,
            defender: state.opponent,
            defenderDecision: opponentDecision
        )
        let opponentDamage = damage(
            attacker: state.opponent,
            attackerDecision: opponentDecision,
            defender: state.player,
            defenderDecision: playerDecision
        )
        player.receiveDamage(opponentDamage)
        opponent.receiveDamage(playerDamage)

        let playerEnergyRecovered = playerDecision.action == .charge ? balance.chargeRecovery(for: playerDecision.timing) : 0
        let opponentEnergyRecovered = opponentDecision.action == .charge ? balance.chargeRecovery(for: opponentDecision.timing) : 0
        player.recoverEnergy(playerEnergyRecovered)
        opponent.recoverEnergy(opponentEnergyRecovered)

        let outcome = outcome(player: player, opponent: opponent)
        let nextState = BattleState(player: player, opponent: opponent, round: state.round + 1, outcome: outcome)
        let result = RoundResult(
            round: state.round,
            player: CombatantRoundResult(
                decision: playerDecision,
                energySpent: playerEnergySpent,
                energyRecovered: playerEnergyRecovered,
                damageDealt: playerDamage,
                hpBefore: playerHPBefore,
                hpAfter: player.currentHP,
                energyBefore: playerEnergyBefore,
                energyAfter: player.currentEnergy
            ),
            opponent: CombatantRoundResult(
                decision: opponentDecision,
                energySpent: opponentEnergySpent,
                energyRecovered: opponentEnergyRecovered,
                damageDealt: opponentDamage,
                hpBefore: opponentHPBefore,
                hpAfter: opponent.currentHP,
                energyBefore: opponentEnergyBefore,
                energyAfter: opponent.currentEnergy
            ),
            outcome: outcome
        )
        return BattleRoundResolution(state: nextState, result: result)
    }

    private func makeCombatantState(for creature: Creature) -> CombatantState {
        CombatantState(
            creature: creature,
            maximumHP: balance.maximumHP(for: creature),
            maximumEnergy: balance.maximumEnergy(for: creature)
        )
    }

    private func energyCost(for action: BattleAction) -> Int {
        switch action {
        case .attack: balance.attackEnergyCost
        case .defend: balance.defenseEnergyCost
        case .charge: 0
        }
    }

    private func damage(
        attacker: CombatantState,
        attackerDecision: BattleDecision,
        defender: CombatantState,
        defenderDecision: BattleDecision
    ) -> Int {
        guard attackerDecision.action == .attack else { return 0 }
        let unguardedDamage = balance.attackDamage(for: attacker.creature, timing: attackerDecision.timing)
        guard defenderDecision.action == .defend else { return unguardedDamage }
        let reduction = balance.defenseReductionPercent(for: defender.creature, timing: defenderDecision.timing)
        return max(1, balance.applyingPercent(unguardedDamage, percent: 100 - reduction))
    }

    private func outcome(player: CombatantState, opponent: CombatantState) -> BattleOutcome? {
        switch (player.currentHP == 0, opponent.currentHP == 0) {
        case (true, true): .draw
        case (false, true): .playerVictory
        case (true, false): .opponentVictory
        case (false, false): nil
        }
    }
}

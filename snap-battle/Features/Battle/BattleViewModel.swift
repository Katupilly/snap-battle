import Foundation
import Observation

@MainActor
@Observable
final class BattleViewModel {
    enum Phase: Equatable {
        case choosingAction
        case timing(BattleAction)
        case resolving
        case showingRoundResult
        case finished(BattleOutcome)
    }

    private let engine: BattleEngine
    private let timingEvaluator: TimingEvaluator
    private var opponentChooser: any BattleActionChoosing
    private let playerCreature: Creature
    private let opponentCreature: Creature

    private(set) var state: BattleState
    private(set) var phase: Phase = .choosingAction
    private(set) var roundResult: RoundResult?
    private(set) var selectedAction: BattleAction?
    private(set) var errorMessage: String?

    init(
        player: Creature,
        opponent: Creature? = nil,
        engine: BattleEngine? = nil,
        timingEvaluator: TimingEvaluator? = nil,
        opponentChooser: (any BattleActionChoosing)? = nil
    ) {
        let engine = engine ?? BattleEngine()
        let opponent = opponent ?? BattleDemoOpponent.creature
        self.playerCreature = player
        self.opponentCreature = opponent
        self.engine = engine
        self.timingEvaluator = timingEvaluator ?? TimingEvaluator(balance: engine.balance)
        self.opponentChooser = opponentChooser ?? BattleAIDecisionProvider()
        state = engine.makeInitialState(player: player, opponent: opponent)
    }

    var validPlayerActions: Set<BattleAction> {
        engine.validActions(for: state.player)
    }

    var balance: BattleBalance { engine.balance }

    var isChoosingAction: Bool {
        phase == .choosingAction
    }

    func chooseAction(_ action: BattleAction) {
        guard phase == .choosingAction, validPlayerActions.contains(action) else { return }
        selectedAction = action
        errorMessage = nil
        phase = .timing(action)
    }

    func confirmTiming(normalizedPosition: Double) {
        guard case .timing(let action) = phase else { return }
        phase = .resolving
        let timing = timingEvaluator.evaluate(normalizedPosition: normalizedPosition, agility: state.player.creature.stats.agility)
        let playerDecision = BattleDecision(action: action, timing: timing)
        let opponentDecision = opponentChooser.chooseDecision(for: state.opponent, opponent: state.player, round: state.round)

        do {
            let resolution = try engine.resolveRound(
                state: state,
                playerDecision: playerDecision,
                opponentDecision: opponentDecision
            )
            state = resolution.state
            roundResult = resolution.result
            selectedAction = nil
            phase = resolution.state.outcome.map(Phase.finished) ?? .showingRoundResult
        } catch {
            errorMessage = "Unable to resolve this round."
            phase = .choosingAction
        }
    }

    func continueBattle() {
        guard phase == .showingRoundResult else { return }
        roundResult = nil
        errorMessage = nil
        phase = .choosingAction
    }

    func restart() {
        state = engine.makeInitialState(player: playerCreature, opponent: opponentCreature)
        phase = .choosingAction
        roundResult = nil
        selectedAction = nil
        errorMessage = nil
    }
}

final class BattleAIDecisionProvider: BattleActionChoosing {
    private var ai = SimpleBattleAI(random: SystemRandomNumberProvider())

    func chooseDecision(for actor: CombatantState, opponent: CombatantState, round: Int) -> BattleDecision {
        ai.chooseDecision(for: actor, opponent: opponent, round: round)
    }
}

import SwiftUI

struct BattleView: View {
    @State private var model: BattleViewModel
    @Environment(\.dismiss) private var dismiss

    init(player: Creature) {
        _model = State(initialValue: BattleViewModel(player: player))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CombatantHUD(
                    combatant: model.state.opponent,
                    action: model.roundResult?.opponent.decision.action,
                    receivedDamage: (model.roundResult?.player.damageDealt ?? 0) > 0,
                    recoveredEnergy: (model.roundResult?.opponent.energyRecovered ?? 0) > 0
                )
                CreaturePortrait(creature: model.state.opponent.creature)
                battleContent
                CreaturePortrait(creature: model.state.player.creature)
                CombatantHUD(
                    combatant: model.state.player,
                    action: model.roundResult?.player.decision.action,
                    receivedDamage: (model.roundResult?.opponent.damageDealt ?? 0) > 0,
                    recoveredEnergy: (model.roundResult?.player.energyRecovered ?? 0) > 0
                )
                BattleActionControls(
                    validActions: model.validPlayerActions,
                    isEnabled: model.isChoosingAction,
                    balance: model.balance,
                    chooseAction: model.chooseAction
                )
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
            }
            .padding()
        }
        .navigationTitle("Battle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Exit") { dismiss() }
            }
        }
        .overlay {
            if case .finished(let outcome) = model.phase {
                Color.black.opacity(0.22).ignoresSafeArea()
                BattleEndOverlay(outcome: outcome, completedRounds: model.state.round - 1, restart: model.restart) { dismiss() }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.phase)
        .sensoryFeedback(.success, trigger: model.state.outcome) { _, outcome in
            outcome == .playerVictory
        }
    }

    @ViewBuilder
    private var battleContent: some View {
        switch model.phase {
        case .choosingAction:
            Text("Choose your action for round \(model.state.round).")
                .font(.subheadline.weight(.medium))
        case .timing:
            TimingBar(
                round: model.state.round,
                agility: model.state.player.creature.stats.agility,
                balance: model.balance,
                confirm: model.confirmTiming
            )
        case .resolving:
            ProgressView("Resolving round…")
        case .showingRoundResult:
            if let result = model.roundResult {
                RoundSummaryView(result: result, continueBattle: model.continueBattle)
            }
        case .finished:
            if let result = model.roundResult {
                RoundSummaryView(result: result, continueBattle: {})
                    .hidden()
            }
        }
    }
}

#Preview {
    NavigationStack {
        BattleView(player: BattleDemoOpponent.creature)
    }
}

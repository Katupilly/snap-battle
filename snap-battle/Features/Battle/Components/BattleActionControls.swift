import SwiftUI

struct BattleActionControls: View {
    let validActions: Set<BattleAction>
    let isEnabled: Bool
    let balance: BattleBalance
    let chooseAction: (BattleAction) -> Void

    var body: some View {
        HStack(spacing: 10) {
            actionButton(.attack, detail: "-\(balance.attackEnergyCost) energy")
            actionButton(.defend, detail: "-\(balance.defenseEnergyCost) energy")
            actionButton(.charge, detail: "+1–3 energy")
        }
    }

    private func actionButton(_ action: BattleAction, detail: String) -> some View {
        Button {
            chooseAction(action)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.symbolName)
                Text(action.title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint(for: action))
        .disabled(!isEnabled || !validActions.contains(action))
        .accessibilityLabel(action.title)
        .accessibilityHint(accessibilityHint(for: action, detail: detail))
    }

    private func tint(for action: BattleAction) -> Color {
        switch action {
        case .attack: .red
        case .defend: .blue
        case .charge: .green
        }
    }

    private func accessibilityHint(for action: BattleAction, detail: String) -> String {
        validActions.contains(action) ? detail : "Unavailable: not enough energy."
    }
}

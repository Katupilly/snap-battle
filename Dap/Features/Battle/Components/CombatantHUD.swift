import SwiftUI

struct CombatantHUD: View {
    let combatant: CombatantState
    let action: BattleAction?
    let receivedDamage: Bool
    let recoveredEnergy: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(combatant.creature.name)
                    .font(.headline.monospaced())
                Spacer()
                if let action {
                    Label(action.title, systemImage: action.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(action == .defend ? .blue : .secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("HP", systemImage: "heart.fill")
                    Spacer()
                    Text("\(combatant.currentHP) / \(combatant.maximumHP)")
                        .monospacedDigit()
                }
                ProgressView(value: Double(combatant.currentHP), total: Double(combatant.maximumHP))
                    .tint(.red)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: combatant.currentHP)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Health")
            .accessibilityValue("\(combatant.currentHP) of \(combatant.maximumHP)")

            HStack(spacing: 5) {
                Label("Energy", systemImage: "bolt.fill")
                Spacer()
                ForEach(0..<combatant.maximumEnergy, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < combatant.currentEnergy ? Color.yellow : Color.secondary.opacity(0.2))
                        .frame(width: 18, height: 10)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: combatant.currentEnergy)
                }
            }
            .font(.caption.weight(.medium))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Energy")
            .accessibilityValue("\(combatant.currentEnergy) of \(combatant.maximumEnergy)")
        }
        .padding(12)
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
        .scaleEffect(receivedDamage && !reduceMotion ? 0.97 : 1)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(recoveredEnergy ? .yellow : (action == .defend ? .blue.opacity(0.7) : .clear), lineWidth: 2)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: receivedDamage)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: recoveredEnergy)
    }
}

extension BattleAction {
    var title: String {
        switch self {
        case .attack: "Attack"
        case .defend: "Defend"
        case .charge: "Charge"
        }
    }

    var symbolName: String {
        switch self {
        case .attack: "burst.fill"
        case .defend: "shield.fill"
        case .charge: "bolt.fill"
        }
    }
}

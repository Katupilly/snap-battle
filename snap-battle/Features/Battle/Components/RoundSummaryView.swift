import SwiftUI

struct RoundSummaryView: View {
    let result: RoundResult
    let continueBattle: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Round \(result.round)")
                .font(.headline.monospaced())
            Text("You: \(result.player.decision.action.title) · \(result.player.decision.timing.rawValue.uppercased()) · Opponent: \(result.opponent.decision.action.title)")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Continue", action: continueBattle)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }

    private var summary: String {
        var parts = ["You dealt \(result.player.damageDealt) damage", "received \(result.opponent.damageDealt)"]
        if result.player.energyRecovered > 0 { parts.append("recovered \(result.player.energyRecovered) energy") }
        if result.opponent.energyRecovered > 0 { parts.append("opponent recovered \(result.opponent.energyRecovered) energy") }
        return parts.joined(separator: " · ")
    }
}

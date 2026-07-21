import SwiftUI

struct BattleEndOverlay: View {
    let outcome: BattleOutcome
    let completedRounds: Int
    let restart: () -> Void
    let exit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbolName)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(tint)
            Text(title).font(.title.bold())
            Text("Battle finished after \(completedRounds) round\(completedRounds == 1 ? "" : "s").")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Play again", action: restart).buttonStyle(.borderedProminent)
            Button("Exit battle", action: exit).buttonStyle(.bordered)
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .shadow(radius: 16)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch outcome {
        case .playerVictory: "Victory"
        case .opponentVictory: "Defeat"
        case .draw: "Draw"
        }
    }

    private var symbolName: String {
        switch outcome {
        case .playerVictory: "crown.fill"
        case .opponentVictory: "xmark.seal.fill"
        case .draw: "equal.circle.fill"
        }
    }

    private var tint: Color {
        switch outcome {
        case .playerVictory: .yellow
        case .opponentVictory: .red
        case .draw: .blue
        }
    }
}

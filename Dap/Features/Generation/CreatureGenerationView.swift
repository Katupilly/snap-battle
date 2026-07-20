import SwiftUI

struct CreatureGenerationView: View {
    let stage: ProcessingStage
    let cancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.12))
                    .frame(width: 92, height: 92)
                Circle()
                    .stroke(.tint.opacity(0.35), lineWidth: 2)
                    .frame(width: 66, height: 66)
                    .scaleEffect(isPulsing && !reduceMotion ? 1.08 : 1)
                    .opacity(isPulsing && !reduceMotion ? 0.55 : 1)
                Image(systemName: "wand.and.stars")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }

            VStack(spacing: 6) {
                Text(stage.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("A little battle partner is taking shape.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Cancel", action: cancel)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Stops creating the creature")
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stage.title). A little battle partner is taking shape.")
    }
}

private extension ProcessingStage {
    var title: String {
        switch self {
        case .extractingSubject: "Observing the creature…"
        case .extractingFeatures: "Discovering its traits…"
        case .generatingCreature: "Bringing it to life…"
        case .calculatingStats: "Preparing for battle…"
        }
    }
}

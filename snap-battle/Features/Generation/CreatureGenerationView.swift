import SwiftUI

struct CreatureGenerationView: View {
    let stage: ProcessingStage
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ScanningOverlay {
                RoundedRectangle(cornerRadius: 12).fill(.tint.opacity(0.08)).frame(height: 90).overlay { Image(systemName: "wand.and.stars").font(.title2).foregroundStyle(.tint) }
            }
            Text(stage.rawValue).font(.headline)
            Text("On-device processing").font(.caption).foregroundStyle(.secondary)
            Button("Cancel", action: cancel).buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

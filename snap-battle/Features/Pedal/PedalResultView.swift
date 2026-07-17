import SwiftUI

struct PedalResultView: View {
    let model: PhotoPedalViewModel
    let pedal: PhotoPedal
    let cover: UIImage
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: cover).resizable().interpolation(.none).scaledToFit().clipShape(.rect(cornerRadius: 20))
                    .accessibilityLabel("Capa 2-bit do pedal")
                VStack(spacing: 8) {
                    Text(pedal.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text(pedal.description).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    enrichmentStatus(model.semanticEnrichmentState)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: pedal.name)
                .accessibilityElement(children: .combine)
                Text("\(pedal.sequence.harmony.rootName) · \(pedal.sequence.harmony.scale.displayName) · \(pedal.sequence.harmony.bpm) BPM")
                    .font(.subheadline.weight(.semibold))
                StepGrid(sequence: pedal.sequence)
                Picker("Efeito", selection: $model.selectedEffect) {
                    ForEach(PedalEffect.allCases) { effect in Text(effect.displayName).tag(effect) }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.selectedEffect) { _, effect in model.chooseEffect(effect) }
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Intensidade"); Spacer(); Text("\(Int(model.effectMix(for: model.selectedEffect).rounded()))%") }
                        .font(.subheadline.weight(.medium))
                    Slider(value: Binding(get: { model.effectMix(for: model.selectedEffect) }, set: { model.updateEffectMix($0) }), in: 0 ... 100, step: 1)
                        .accessibilityLabel("Intensidade de \(model.selectedEffect.displayName)")
                }
                Button("Tocar pedal", systemImage: "play.fill") { model.play() }.buttonStyle(.borderedProminent).controlSize(.large)
                Button("Ver na Gallery", systemImage: "square.grid.2x2") { onDone() }.buttonStyle(.bordered)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func enrichmentStatus(_ state: PhotoPedalViewModel.SemanticEnrichmentState) -> some View {
        switch state {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.mini)
                Text("Refinando nome...")
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Refinando nome e descrição")
        case .succeeded:
            Text("Nome atualizado")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Nome e descrição atualizados")
        case .failed, .cancelled, .staleIgnored, .notStarted:
            EmptyView()
        }
    }
}

private struct StepGrid: View {
    let sequence: PedalSequence
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0 ..< PedalSequence.rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0 ..< PedalSequence.steps, id: \.self) { step in
                        let note = sequence.notes.first { $0.row == row && $0.step == step }
                        GridCell(velocity: note?.velocity)
                    }
                }
            }
        }
        .accessibilityLabel("Grid da sequência com \(sequence.notes.count) notas")
    }
}

private struct GridCell: View {
    let velocity: Float?
    var body: some View {
        let color: Color = velocity.map { Color.accentColor.opacity(Double($0)) } ?? Color.secondary.opacity(0.16)
        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 15, height: 15)
    }
}

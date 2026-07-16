import SwiftUI

struct PedalResultView: View {
    let model: PhotoPedalViewModel
    let pedal: PhotoPedal
    let cover: UIImage

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: cover).resizable().interpolation(.none).scaledToFit().clipShape(.rect(cornerRadius: 20))
                    .accessibilityLabel("Capa 2-bit do pedal")
                Text(pedal.name).font(.largeTitle.bold())
                Text(pedal.description).multilineTextAlignment(.center).foregroundStyle(.secondary)
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
                Button("Criar outro", systemImage: "camera") { model.reset() }.buttonStyle(.bordered)
            }
            .padding(24)
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

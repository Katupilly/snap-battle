import SwiftUI

struct PedalPickerView: View {
    let pedals: [StoredPedal]
    let addPedal: (StoredPedal) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if pedals.isEmpty {
                    ContentUnavailableView(
                        "Biblioteca vazia",
                        systemImage: "square.grid.2x2",
                        description: Text("Capture ou importe pedais antes de montar um pedalboard.")
                    )
                } else {
                    List(pedals) { pedal in
                        Button {
                            addPedal(pedal)
                        } label: {
                            HStack(spacing: 12) {
                                Image(uiImage: pedal.cover)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 54, height: 54)
                                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pedal.pedal.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text("\(pedal.pedal.effect.displayName) · \(pedal.pedal.dominantPitchClass.symbol)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Adicionar \(pedal.pedal.name), nota predominante \(pedal.pedal.dominantPitchClass.accessibilityName)")
                        .accessibilityHint("Adiciona este pedal ao pedalboard")
                    }
                }
            }
            .navigationTitle("Adicionar pedal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

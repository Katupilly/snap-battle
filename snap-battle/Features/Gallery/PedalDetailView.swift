import SwiftUI

struct PedalDetailView: View {
    let itemID: UUID
    let model: GalleryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDeletion = false

    private var item: StoredPedal? {
        model.state.pedals.first { $0.id == itemID }
    }

    var body: some View {
        Group {
            if let item {
                detailContent(for: item)
            } else {
                ContentUnavailableView("Pedal indisponível", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Pedal")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailContent(for item: StoredPedal) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: item.cover).resizable().interpolation(.none).scaledToFit().clipShape(.rect(cornerRadius: 20))
                    .accessibilityLabel("Capa 2-bit de \(item.pedal.name)")
                Text(item.pedal.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(item.pedal.description).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("\(item.pedal.effect.displayName) selecionado").font(.subheadline.weight(.semibold))
                Text(isPlaying ? "Reprodução em andamento" : "Pronto para tocar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(isPlaying ? "Reprodução em andamento" : "Pronto para tocar")
                HStack(spacing: 12) {
                    Button("Tocar", systemImage: "play.fill", action: play)
                        .buttonStyle(.borderedProminent)
                    Button("Parar", systemImage: "stop.fill", action: stop)
                        .buttonStyle(.bordered)
                        .disabled(!isPlaying)
                }
                .controlSize(.large)
                Button("Excluir", systemImage: "trash", role: .destructive) {
                    isConfirmingDeletion = true
                }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityHint("Pede confirmação antes de remover este pedal")
            }
            .padding(24)
        }
        .alert("Excluir pedal?", isPresented: $isConfirmingDeletion) {
            Button("Excluir", role: .destructive, action: delete)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("\(item.pedal.name) será removido da Gallery.")
        }
    }

    private var isPlaying: Bool {
        model.playingID == itemID
    }

    private func play() {
        guard let item else { return }
        model.quickPlay(item)
    }

    private func stop() {
        guard let item else { return }
        model.stop(item)
    }

    private func delete() {
        guard let item, model.delete(item) else { return }
        dismiss()
    }
}

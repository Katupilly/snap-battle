import SwiftUI

struct GalleryView: View {
    let model: GalleryViewModel
    @State private var itemPendingDeletion: StoredPedal?

    var body: some View {
        content(for: model.state)
        .navigationTitle("Gallery")
        .navigationDestination(for: UUID.self) { id in
            if let item = model.state.pedals.first(where: { $0.id == id }) {
                PedalDetailView(item: item, play: { model.quickPlay(item) })
            } else {
                ContentUnavailableView("Pedal indisponível", systemImage: "exclamationmark.triangle")
            }
        }
        .alert("Excluir pedal?", isPresented: Binding(get: { itemPendingDeletion != nil }, set: { if !$0 { itemPendingDeletion = nil } }), presenting: itemPendingDeletion) { item in
            Button("Excluir", role: .destructive) { model.delete(item); itemPendingDeletion = nil }
            Button("Cancelar", role: .cancel) { itemPendingDeletion = nil }
        } message: { item in Text("\(item.pedal.name) será removido da Gallery.") }
        .alert("Não foi possível excluir", isPresented: Binding(get: { model.deletionErrorMessage != nil }, set: { if !$0 { model.deletionErrorMessage = nil } })) {
            Button("OK", role: .cancel) { model.deletionErrorMessage = nil }
        } message: { Text(model.deletionErrorMessage ?? "") }
        .alert("Não foi possível tocar", isPresented: Binding(get: { model.playbackErrorMessage != nil }, set: { if !$0 { model.playbackErrorMessage = nil } })) {
            Button("OK", role: .cancel) { model.playbackErrorMessage = nil }
        } message: { Text(model.playbackErrorMessage ?? "") }
    }

    @ViewBuilder
    private func content(for state: GalleryViewModel.State) -> some View {
        switch state {
            case .loading:
                ProgressView("Carregando pedais")
                    .accessibilityLabel("Carregando pedais")
            case .empty:
                ContentUnavailableView("Sua Gallery está vazia", systemImage: "square.grid.2x2", description: Text("Crie um pedal para encontrá-lo aqui."))
            case .blockingError(let message):
                VStack(spacing: 16) {
                    ContentUnavailableView("Não foi possível carregar a Gallery", systemImage: "exclamationmark.triangle", description: Text(message))
                    Button("Tentar novamente") { model.reload() }
                }
            case .content(let pedals):
                galleryList(pedals)
            case .partialError(let pedals, let message):
                VStack(spacing: 0) {
                    Label("Alguns pedais não puderam ser carregados.", systemImage: "exclamationmark.triangle")
                        .font(.footnote).padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.yellow.opacity(0.15)).accessibilityLabel(message)
                    galleryList(pedals)
                }
        }
    }

    @ViewBuilder
    private func galleryList(_ pedals: [StoredPedal]) -> some View {
        List(pedals) { item in
            GalleryCard(item: item, isPlaying: model.playingID == item.id, play: { model.quickPlay(item) }, delete: { itemPendingDeletion = item })
        }
        .refreshable { model.reload() }
    }
}

private struct PedalDetailView: View {
    let item: StoredPedal
    let play: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: item.cover).resizable().interpolation(.none).scaledToFit().clipShape(.rect(cornerRadius: 20))
                    .accessibilityLabel("Capa 2-bit de \(item.pedal.name)")
                Text(item.pedal.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(item.pedal.description).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("\(item.pedal.effect.displayName) selecionado").font(.subheadline.weight(.semibold))
                Button("Tocar pedal", systemImage: "play.fill", action: play).buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding(24)
        }
        .navigationTitle("Pedal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GalleryCard: View {
    let item: StoredPedal
    let isPlaying: Bool
    let play: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: item.cover).resizable().interpolation(.none).scaledToFill().frame(width: 72, height: 72).clipShape(.rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                NavigationLink(value: item.id) {
                    Text(item.pedal.name).font(.headline).multilineTextAlignment(.leading)
                }
                .accessibilityLabel("Abrir detalhes de \(item.pedal.name)")
                Text(isPlaying ? "Tocando" : "Pronto para tocar").font(.footnote).foregroundStyle(.secondary)
                    .accessibilityLabel(isPlaying ? "Reprodução em andamento" : "Pronto para tocar")
                HStack {
                    Button("Tocar", systemImage: "play.fill", action: play)
                        .accessibilityLabel("Tocar \(item.pedal.name)")
                    Button("Excluir", systemImage: "trash", role: .destructive, action: delete)
                        .accessibilityLabel("Excluir \(item.pedal.name)")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

struct JamPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Sua Jam começa aqui", systemImage: "music.note.list", description: Text("Em breve você poderá combinar seus pedais para criar uma música."))
            .navigationTitle("Jam")
            .accessibilityLabel("Jam. Em breve você poderá combinar seus pedais para criar uma música.")
    }
}

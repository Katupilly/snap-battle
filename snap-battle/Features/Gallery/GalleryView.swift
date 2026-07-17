import SwiftUI

struct GalleryView: View {
    let model: GalleryViewModel
    let beginCapture: () -> Void
    let thumbnailLoader: ThumbnailLoader
    let transitionNamespace: Namespace.ID
    @State private var itemPendingDeletion: StoredPedal?

    var body: some View {
        content(for: model.state)
        .navigationTitle("Biblioteca")
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
                LibraryGridView(
                    state: .loading,
                    thumbnailLoader: thumbnailLoader,
                    assetProvider: model.thumbnailAsset(for:),
                    transitionNamespace: transitionNamespace
                )
            case .empty:
                LibraryGridView(
                    state: .empty,
                    thumbnailLoader: thumbnailLoader,
                    assetProvider: model.thumbnailAsset(for:),
                    transitionNamespace: transitionNamespace
                )
            case .blockingError(let message):
                LibraryGridView(
                    state: .error(message: message),
                    onRetry: { Task { await model.reloadAsync() } },
                    thumbnailLoader: thumbnailLoader,
                    assetProvider: model.thumbnailAsset(for:),
                    transitionNamespace: transitionNamespace
                )
            case .content(let pedals):
                libraryGrid(state: .content(pedals))
            case .partialError(let pedals, let message):
                libraryGrid(state: .partialError(pedals, message: message))
        }
    }

    private func libraryGrid(state: LibraryGridState) -> some View {
        LibraryGridView(
            state: state,
            onRetry: { Task { await model.reloadAsync() } },
            thumbnailLoader: thumbnailLoader,
            assetProvider: model.thumbnailAsset(for:),
            transitionNamespace: transitionNamespace
        )
        .refreshable { await model.reloadAsync() }
    }
}

struct JamPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Sua Jam começa aqui", systemImage: "music.note.list", description: Text("Em breve você poderá combinar seus pedais para criar uma música."))
            .navigationTitle("Jam")
            .accessibilityLabel("Jam. Em breve você poderá combinar seus pedais para criar uma música.")
    }
}

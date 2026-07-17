import SwiftUI

struct GalleryView: View {
    let model: GalleryViewModel
    let beginCapture: () -> Void
    let thumbnailLoader: ThumbnailLoader
    let transitionNamespace: Namespace.ID
    let imageProvider: LibraryGridImageProvider
    let assetProvider: ((UUID) -> PersistedImageAsset?)?
    @State private var itemPendingDeletion: StoredPedal?

    init(
        model: GalleryViewModel,
        beginCapture: @escaping () -> Void,
        thumbnailLoader: ThumbnailLoader,
        transitionNamespace: Namespace.ID,
        imageProvider: LibraryGridImageProvider = .persistedCover,
        assetProvider: ((UUID) -> PersistedImageAsset?)? = nil
    ) {
        self.model = model
        self.beginCapture = beginCapture
        self.thumbnailLoader = thumbnailLoader
        self.transitionNamespace = transitionNamespace
        self.imageProvider = imageProvider
        self.assetProvider = assetProvider
    }

    var body: some View {
        ZStack {
            CanvasGridBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            content(for: model.state)
        }
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
                    imageProvider: imageProvider,
                    thumbnailLoader: thumbnailLoader,
                    assetProvider: asset(for:),
                    transitionNamespace: transitionNamespace
                )
            case .empty:
                LibraryGridView(
                    state: .empty,
                    imageProvider: imageProvider,
                    thumbnailLoader: thumbnailLoader,
                    assetProvider: asset(for:),
                    transitionNamespace: transitionNamespace
                )
            case .blockingError(let message):
                LibraryGridView(
                    state: .error(message: message),
                    onRetry: { Task { await model.reloadAsync() } },
                    imageProvider: imageProvider,
                    thumbnailLoader: thumbnailLoader,
                    assetProvider: asset(for:),
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
            imageProvider: imageProvider,
            thumbnailLoader: thumbnailLoader,
            assetProvider: asset(for:),
            transitionNamespace: transitionNamespace
        )
        .refreshable { await model.reloadAsync() }
    }

    private func asset(for id: UUID) -> PersistedImageAsset? {
        assetProvider?(id) ?? model.thumbnailAsset(for: id)
    }
}

struct JamPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Sua Jam começa aqui", systemImage: "music.note.list", description: Text("Em breve você poderá combinar seus pedais para criar uma música."))
            .navigationTitle("Jam")
            .accessibilityLabel("Jam. Em breve você poderá combinar seus pedais para criar uma música.")
    }
}

#if DEBUG

@MainActor
private final class GalleryPreviewPlayer: PedalPlaying {
    private(set) var isPlaying = false

    func play(_ pedal: PhotoPedal) throws {
        isPlaying = true
    }

    func stop() {
        isPlaying = false
    }
}

@MainActor
private func makeGalleryPreviewModel(state: GalleryViewModel.State) -> GalleryViewModel {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("gallery-preview-\(UUID().uuidString)", isDirectory: true)
    let model = GalleryViewModel(store: PedalStore(directory: directory), player: GalleryPreviewPlayer())
    model.state = state
    return model
}

private func makePreviewPedals(count: Int) -> [StoredPedal] {
    (0..<count).map { index in
        StoredPedal(
            pedal: LibraryDebugFixtureStore.pedal(index: index, dataset: .small),
            cover: LibraryDebugFixtureStore.cover(index: index)
        )
    }
}

private struct GalleryPreviewScreen: View {
    let state: GalleryViewModel.State
    @Namespace private var transitionNamespace

    var body: some View {
        NavigationStack {
            GalleryView(
                model: makeGalleryPreviewModel(state: state),
                beginCapture: {},
                thumbnailLoader: ThumbnailLoader(),
                transitionNamespace: transitionNamespace
            )
        }
    }
}

#Preview("Gallery Empty Light") {
    GalleryPreviewScreen(state: .empty)
}

#Preview("Gallery Empty Dark") {
    GalleryPreviewScreen(state: .empty)
    .preferredColorScheme(.dark)
}

#Preview("Gallery Content Light") {
    GalleryPreviewScreen(state: .content(makePreviewPedals(count: 18)))
}

#Preview("Gallery Content Dark") {
    GalleryPreviewScreen(state: .content(makePreviewPedals(count: 18)))
    .preferredColorScheme(.dark)
}

#endif

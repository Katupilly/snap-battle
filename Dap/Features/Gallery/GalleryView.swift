import PhotosUI
import SwiftUI

struct GalleryView: View {
    let model: GalleryViewModel
    let thumbnailLoader: ThumbnailLoader
    let transitionNamespace: Namespace.ID
    let imageProvider: LibraryGridImageProvider
    let assetProvider: ((UUID) -> PersistedImageAsset?)?
    let addToJam: ([UUID]) -> Void
    let isActive: Bool
    @Binding private var selectedImportItem: PhotosPickerItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingDeletionIDs: [UUID]?
    @State private var entryHaptics = GalleryEntryHaptics()
    @State private var entryPresentationID = 0
    @State private var entryIsPending = false

    init(
        model: GalleryViewModel,
        thumbnailLoader: ThumbnailLoader,
        transitionNamespace: Namespace.ID,
        imageProvider: LibraryGridImageProvider = .persistedCover,
        assetProvider: ((UUID) -> PersistedImageAsset?)? = nil,
        addToJam: @escaping ([UUID]) -> Void = { _ in },
        isActive: Bool = true,
        selectedImportItem: Binding<PhotosPickerItem?> = .constant(nil)
    ) {
        self.model = model
        self.thumbnailLoader = thumbnailLoader
        self.transitionNamespace = transitionNamespace
        self.imageProvider = imageProvider
        self.assetProvider = assetProvider
        self.addToJam = addToJam
        self.isActive = isActive
        self._selectedImportItem = selectedImportItem
    }

    var body: some View {
        content(for: model.state)
            .navigationTitle(model.isSelecting && !model.selectedIDs.isEmpty ? "\(model.selectedIDs.count) Selected" : "Gallery")
            .toolbar {
                if !model.isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        PhotosPicker(selection: $selectedImportItem, matching: .images) {
                            Label("Import Photos", systemImage: "plus")
                        }
                        .accessibilityIdentifier("gallery.import")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if model.isSelecting {
                        Button("Cancel Selection", systemImage: "xmark") { model.cancelSelection() }
                            .accessibilityIdentifier("gallery.cancel-selection")
                    } else if !model.state.pedals.isEmpty {
                        Button("Select Photos", systemImage: "checkmark.circle") { model.beginSelection() }
                            .accessibilityIdentifier("gallery.select")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.isSelecting && !model.selectedIDs.isEmpty {
                    GallerySelectionBar(
                        count: model.selectedIDs.count,
                        shareURLs: model.shareURLs(for: model.selectedIDs),
                        addToJam: { addToJam(Array(model.selectedIDs)) },
                        delete: { requestDelete(Array(model.selectedIDs)) }
                    )
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.isSelecting)
            .alert(
                deleteTitle,
                isPresented: Binding(
                    get: { pendingDeletionIDs != nil },
                    set: { if !$0 { pendingDeletionIDs = nil } }
                )
            ) {
                Button(deleteActionTitle, role: .destructive) { confirmDelete() }
                Button("Cancel", role: .cancel) { pendingDeletionIDs = nil }
            } message: {
                Text(deleteMessage)
            }
            .alert("Couldn’t Delete Photos", isPresented: Binding(get: { model.deletionErrorMessage != nil }, set: { if !$0 { model.deletionErrorMessage = nil } })) {
                Button("OK", role: .cancel) { model.deletionErrorMessage = nil }
            } message: { Text(model.deletionErrorMessage ?? "") }
            .alert("Couldn’t Play Photo", isPresented: Binding(get: { model.playbackErrorMessage != nil }, set: { if !$0 { model.playbackErrorMessage = nil } })) {
                Button("OK", role: .cancel) { model.playbackErrorMessage = nil }
            } message: { Text(model.playbackErrorMessage ?? "") }
            .onAppear { prepareEntryPresentation() }
            .onChange(of: isActive) { _, active in
                if active { prepareEntryPresentation() } else { resetEntryPresentation() }
            }
            .onChange(of: model.state.pedals.map(\.id)) { _, _ in startEntryPresentationIfPossible() }
            .onDisappear { resetEntryPresentation() }
    }

    @ViewBuilder
    private func content(for state: GalleryViewModel.State) -> some View {
        switch state {
        case .loading:
            LibraryGridView(state: .loading, imageProvider: imageProvider, thumbnailLoader: thumbnailLoader, assetProvider: asset(for:), transitionNamespace: transitionNamespace)
        case .empty:
            LibraryGridView(state: .empty, imageProvider: imageProvider, thumbnailLoader: thumbnailLoader, assetProvider: asset(for:), transitionNamespace: transitionNamespace)
        case .blockingError(let message):
            LibraryGridView(state: .error(message: message), onRetry: { Task { await model.reloadAsync(reason: .retry) } }, imageProvider: imageProvider, thumbnailLoader: thumbnailLoader, assetProvider: asset(for:), transitionNamespace: transitionNamespace)
        case .content(let pedals):
            libraryGrid(state: .content(pedals))
        case .partialError(let pedals, let message):
            libraryGrid(state: .partialError(pedals, message: message))
        }
    }

    private func libraryGrid(state: LibraryGridState) -> some View {
        LibraryGridView(
            state: state,
            onRetry: { Task { await model.reloadAsync(reason: .retry) } },
            imageProvider: imageProvider,
            thumbnailLoader: thumbnailLoader,
            assetProvider: asset(for:),
            transitionNamespace: transitionNamespace,
            selectionMode: model.isSelecting,
            selectedIDs: model.selectedIDs,
            onToggleSelection: model.toggleSelection(for:),
            onDelete: { requestDelete([$0.id]) },
            onAddToJam: addToJam,
            entryPresentationID: entryPresentationID,
            reduceMotion: reduceMotion
        )
        .refreshable { await model.reloadAsync(reason: .pullToRefresh) }
    }

    private func asset(for id: UUID) -> PersistedImageAsset? {
        assetProvider?(id) ?? model.thumbnailAsset(for: id)
    }

    private func requestDelete(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        pendingDeletionIDs = ids
    }

    private func confirmDelete() {
        guard let ids = pendingDeletionIDs else { return }
        pendingDeletionIDs = nil
        if model.delete(ids: ids), model.isSelecting { model.cancelSelection() }
    }

    private func prepareEntryPresentation() {
        guard isActive else { return }
        entryIsPending = true
        startEntryPresentationIfPossible()
    }

    private func startEntryPresentationIfPossible() {
        guard entryIsPending, !model.state.pedals.isEmpty else { return }
        entryIsPending = false
        entryPresentationID &+= 1
        entryHaptics.play(reduceMotion: reduceMotion)
    }

    private func resetEntryPresentation() {
        entryPresentationID &+= 1
        entryIsPending = false
        entryHaptics.cancel()
    }

    private var deletionCount: Int { pendingDeletionIDs?.count ?? 0 }
    private var deleteTitle: String { deletionCount == 1 ? "Delete Photo?" : "Delete \(deletionCount) Photos?" }
    private var deleteMessage: String { deletionCount == 1 ? "This photo will be permanently deleted from Dap. This action can’t be undone." : "These photos will be permanently deleted from Dap. This action can’t be undone." }
    private var deleteActionTitle: String { deletionCount == 1 ? "Delete Photo" : "Delete \(deletionCount) Photos" }
}

private struct GallerySelectionBar: View {
    let count: Int
    let shareURLs: [URL]
    let addToJam: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if !shareURLs.isEmpty {
                ShareLink(items: shareURLs) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Share Selected Photos")
            }
            Button("Add to Jam", systemImage: "plus.circle", action: addToJam)
                .accessibilityLabel("Add Selected Photos to Jam")
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
                .accessibilityLabel("Delete Selected Photos")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(count) Selected")
    }
}

struct JamPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Sua Jam começa aqui", systemImage: "music.note.list", description: Text("Em breve você poderá combinar seus pedais para criar uma música."))
            .navigationTitle("Jam")
            .accessibilityLabel("Jam. Em breve você poderá combinar seus pedais para criar uma música.")
    }
}

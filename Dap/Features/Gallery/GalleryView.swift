import PhotosUI
import SwiftUI

struct GalleryView: View {
    let model: GalleryViewModel
    let thumbnailLoader: ThumbnailLoader
    let imageProvider: LibraryGridImageProvider
    let assetProvider: ((UUID) -> PersistedImageAsset?)?
    let addToJam: ([UUID]) -> Void
    let isActive: Bool
    let isAtRoot: Bool
    let rootChromePadding: CGFloat
    @Binding private var selectedImportItem: PhotosPickerItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingDeletionIDs: [UUID]?
    @State private var entryHaptics = GalleryEntryHaptics()
    @State private var entryPresentationID = 0
    @State private var entryIsPending = false

    init(
        model: GalleryViewModel,
        thumbnailLoader: ThumbnailLoader,
        imageProvider: LibraryGridImageProvider = .persistedCover,
        assetProvider: ((UUID) -> PersistedImageAsset?)? = nil,
        addToJam: @escaping ([UUID]) -> Void = { _ in },
        isActive: Bool = true,
        isAtRoot: Bool = true,
        transitionNamespace: Namespace.ID? = nil,
        rootChromePadding: CGFloat = 0,
        selectedImportItem: Binding<PhotosPickerItem?> = .constant(nil)
    ) {
        _ = transitionNamespace
        self.model = model
        self.thumbnailLoader = thumbnailLoader
        self.imageProvider = imageProvider
        self.assetProvider = assetProvider
        self.addToJam = addToJam
        self.isActive = isActive
        self.isAtRoot = isAtRoot
        self.rootChromePadding = rootChromePadding
        self._selectedImportItem = selectedImportItem
    }

    var body: some View {
        VStack(spacing: 0) {
            GalleryHeader(
                mode: bottomChromeMode,
                selectedImportItem: $selectedImportItem,
                cancelSelection: model.cancelSelection,
                beginSelection: model.beginSelection
            )
            content(for: model.state)
        }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.isSelecting {
                    GallerySelectionBar(
                        mode: bottomChromeMode,
                        shareURLs: model.shareURLs(for: model.selectedIDs),
                        addToJam: { addToJam(Array(model.selectedIDs)) },
                        delete: { requestDelete(Array(model.selectedIDs)) }
                    )
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.14), value: bottomChromeMode)
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
            .onDisappear {
                resetEntryPresentation()
            }
    }

    @ViewBuilder
    private func content(for state: GalleryViewModel.State) -> some View {
        switch state {
        case .loading:
            LibraryGridView(state: .loading, imageProvider: imageProvider, thumbnailLoader: thumbnailLoader, assetProvider: asset(for:))
        case .empty:
            LibraryGridView(state: .empty, imageProvider: imageProvider, thumbnailLoader: thumbnailLoader, assetProvider: asset(for:))
        case .blockingError(let message):
            LibraryGridView(state: .error(message: message), onRetry: { Task { await model.reloadAsync(reason: .retry) } }, imageProvider: imageProvider, thumbnailLoader: thumbnailLoader, assetProvider: asset(for:))
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
            selectionMode: model.isSelecting,
            selectedIDs: model.selectedIDs,
            onToggleSelection: model.toggleSelection(for:),
            onDelete: { requestDelete([$0.id]) },
            onAddToJam: addToJam,
            bottomContentPadding: rootChromePadding,
            entryPresentationID: isActive ? entryPresentationID : 0,
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
        guard isActive, isAtRoot else { return }
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
        entryIsPending = false
        entryHaptics.cancel()
    }

    private var deletionCount: Int { pendingDeletionIDs?.count ?? 0 }
    private var bottomChromeMode: GalleryBottomChromeMode {
        GalleryBottomChromeMode(isSelecting: model.isSelecting, selectedCount: model.selectedIDs.count)
    }
    private var deleteTitle: String { deletionCount == 1 ? "Delete Photo?" : "Delete \(deletionCount) Photos?" }
    private var deleteMessage: String { deletionCount == 1 ? "This photo will be permanently deleted from Dap. This action can’t be undone." : "These photos will be permanently deleted from Dap. This action can’t be undone." }
    private var deleteActionTitle: String { deletionCount == 1 ? "Delete Photo" : "Delete \(deletionCount) Photos" }
}

private struct GalleryHeader: View {
    let mode: GalleryBottomChromeMode
    @Binding var selectedImportItem: PhotosPickerItem?
    let cancelSelection: () -> Void
    let beginSelection: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Gallery")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                Spacer(minLength: 0)
            }

            HStack {
                if mode == .navigation {
                    PhotosPicker(selection: $selectedImportItem, matching: .images) {
                        GalleryGlassSymbol(systemName: "square.and.arrow.down")
                    }
                    .tint(.primary)
                    .accessibilityLabel("Import Photos")
                    .accessibilityIdentifier("gallery.import")
                }

                Spacer()

                if mode == .navigation {
                    Button(action: beginSelection) {
                        GalleryGlassSymbol(systemName: "checkmark.app")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select Photos")
                    .accessibilityIdentifier("gallery.select")
                } else if mode != .navigation {
                    Button(action: cancelSelection) {
                        GalleryGlassSymbol(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel Selection")
                    .accessibilityIdentifier("gallery.cancel-selection")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if case .selecting(let count) = mode {
                Text(selectedCountText(count))
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("gallery.selection.count")
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 112)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.22), .black.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: 4)
            .ignoresSafeArea(edges: .top)
        }
        .accessibilityElement(children: .contain)
    }

    private func selectedCountText(_ count: Int) -> String {
        count == 1 ? "1 selected" : "\(count) selected"
    }
}

private struct GallerySelectionBar: View {
    let mode: GalleryBottomChromeMode
    let shareURLs: [URL]
    let addToJam: () -> Void
    let delete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.clear, .black.opacity(0.16), .black.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: 5)
            .accessibilityHidden(true)

            if case .selecting(let count) = mode {
                HStack {
                    if !shareURLs.isEmpty {
                        ShareLink(items: shareURLs) {
                            GalleryGlassSymbol(systemName: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        .accessibilityLabel(count == 1 ? "Share Selected Photo" : "Share Selected Photos")
                        .accessibilityIdentifier("gallery.selection.share")
                    } else {
                        GalleryGlassSymbol(systemName: "square.and.arrow.up")
                            .opacity(0.34)
                            .allowsHitTesting(false)
                            .accessibilityLabel(count == 1 ? "Share Selected Photo unavailable" : "Share Selected Photos unavailable")
                    }

                    Spacer()
                    GalleryAddToJamButton(action: addToJam)
                    Spacer()
                    GalleryGlassSymbolAction(systemName: "trash", action: delete)
                        .accessibilityLabel(count == 1 ? "Delete Selected Photo" : "Delete Selected Photos")
                        .accessibilityIdentifier("gallery.selection.delete")
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 116)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("gallery.selection.chrome")
    }

    private var accessibilityLabel: String {
        switch mode {
        case .navigation:
            "Gallery navigation"
        case .selectingEmpty:
            "Selection mode, no photos selected"
        case .selecting(let count):
            count == 1 ? "1 selected" : "\(count) selected"
        }
    }
}

private struct GalleryGlassSymbol: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .background {
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular.tint(.primary.opacity(0.04)).interactive(), in: .circle)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.34), lineWidth: 1)
            }
            .contentShape(.circle)
            .accessibilityHidden(true)
    }
}

private struct GalleryGlassSymbolAction: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GalleryGlassSymbol(systemName: systemName)
        }
        .buttonStyle(.plain)
    }
}

private struct GalleryAddToJamButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image("CustomMusicNoteListBadgePlus")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 27)
                    .accessibilityHidden(true)

                Text("Add to Jam")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(.primary)
            .frame(width: 106, height: 40)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .frame(width: 114, height: 48)
        .background {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.tint(.primary.opacity(0.04)).interactive(), in: .capsule)
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.30), lineWidth: 1)
        }
        .contentShape(.capsule)
        .accessibilityLabel("Add Selected Photos to Jam")
        .accessibilityIdentifier("gallery.selection.addToJam")
    }
}

struct JamPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Sua Jam começa aqui", systemImage: "music.note.list", description: Text("Em breve você poderá combinar seus pedais para criar uma música."))
            .navigationTitle("Jam")
            .accessibilityLabel("Jam. Em breve você poderá combinar seus pedais para criar uma música.")
    }
}

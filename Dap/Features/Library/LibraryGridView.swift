import SwiftUI

enum LibraryGridState {
    case loading
    case empty
    case content([StoredPedal])
    case partialError([StoredPedal], message: String)
    case error(message: String)

    var pedals: [StoredPedal] {
        switch self {
        case .content(let pedals), .partialError(let pedals, _): pedals
        case .loading, .empty, .error: []
        }
    }
}

struct LibraryGridImageProvider {
    let image: (StoredPedal) -> Image?

    init(image: @escaping (StoredPedal) -> Image?) {
        self.image = image
    }

    static let persistedCover = Self { pedal in Image(uiImage: pedal.cover) }

    func callAsFunction(_ pedal: StoredPedal) -> Image? { image(pedal) }
}

struct LibraryGridView: View {
    let state: LibraryGridState
    let calendar: Calendar
    let onRetry: (() -> Void)?
    let imageProvider: LibraryGridImageProvider
    let thumbnailLoader: ThumbnailLoader?
    let assetProvider: (UUID) -> PersistedImageAsset?
    let transitionNamespace: Namespace.ID?
    let selectionMode: Bool
    let selectedIDs: Set<UUID>
    let onToggleSelection: ((UUID) -> Void)?
    let onDelete: ((StoredPedal) -> Void)?
    let onAddToJam: (([UUID]) -> Void)?
    let entryPresentationID: Int
    let reduceMotion: Bool

    @Environment(\.locale) private var locale
    @Environment(\.displayScale) private var displayScale
    @State private var activeEntryPresentationID = 0
    @State private var revealedRowCount = 0

    init(
        state: LibraryGridState,
        calendar: Calendar = .current,
        onRetry: (() -> Void)? = nil,
        imageProvider: LibraryGridImageProvider = .persistedCover,
        thumbnailLoader: ThumbnailLoader? = nil,
        assetProvider: @escaping (UUID) -> PersistedImageAsset? = { _ in nil },
        transitionNamespace: Namespace.ID? = nil,
        selectionMode: Bool = false,
        selectedIDs: Set<UUID> = [],
        onToggleSelection: ((UUID) -> Void)? = nil,
        onDelete: ((StoredPedal) -> Void)? = nil,
        onAddToJam: (([UUID]) -> Void)? = nil,
        entryPresentationID: Int = 0,
        reduceMotion: Bool = false
    ) {
        self.state = state
        self.calendar = calendar
        self.onRetry = onRetry
        self.imageProvider = imageProvider
        self.thumbnailLoader = thumbnailLoader
        self.assetProvider = assetProvider
        self.transitionNamespace = transitionNamespace
        self.selectionMode = selectionMode
        self.selectedIDs = selectedIDs
        self.onToggleSelection = onToggleSelection
        self.onDelete = onDelete
        self.onAddToJam = onAddToJam
        self.entryPresentationID = entryPresentationID
        self.reduceMotion = reduceMotion
    }

    init(
        pedals: [StoredPedal],
        calendar: Calendar = .current,
        imageProvider: LibraryGridImageProvider = .persistedCover,
        thumbnailLoader: ThumbnailLoader? = nil,
        assetProvider: @escaping (UUID) -> PersistedImageAsset? = { _ in nil },
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.init(
            state: pedals.isEmpty ? .empty : .content(pedals),
            calendar: calendar,
            imageProvider: imageProvider,
            thumbnailLoader: thumbnailLoader,
            assetProvider: assetProvider,
            transitionNamespace: transitionNamespace
        )
    }

    var body: some View {
        switch state {
        case .loading: loadingView
        case .empty: emptyView
        case .content(let pedals): gridView(for: pedals)
        case .partialError(let pedals, let message): partialErrorView(pedals: pedals, message: message)
        case .error(let message): errorView(message: message)
        }
    }

    private var loadingView: some View {
        ProgressView("Carregando pedais")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Carregando pedais")
            .accessibilityIdentifier("library.state.loading")
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "Sua biblioteca está vazia",
            systemImage: "square.grid.2x2",
            description: Text("Tire uma foto para criar seu primeiro pedal.")
        )
        .accessibilityIdentifier("library.state.empty")
    }

    @ViewBuilder
    private func partialErrorView(pedals: [StoredPedal], message: String) -> some View {
        VStack(spacing: 0) {
            Label("Alguns pedais não puderam ser carregados.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.yellow.opacity(0.15))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(message)
                .accessibilityIdentifier("library.state.partial-error")

            if pedals.isEmpty { errorContent(message: message) } else { gridView(for: pedals) }
        }
    }

    private func errorView(message: String) -> some View {
        errorContent(message: message)
            .accessibilityIdentifier("library.state.error")
    }

    @ViewBuilder
    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Não foi possível carregar a biblioteca",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            if let onRetry {
                Button("Tentar novamente", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gridView(for pedals: [StoredPedal]) -> some View {
        let ordered = PedalStore.ordered(pedals)
        let participatingRows = min((ordered.count + 2) / 3, 5)
        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, item in
                    LibraryGridCell(
                        item: item,
                        calendar: calendar,
                        locale: locale,
                        displayScale: displayScale,
                        imageProvider: imageProvider,
                        thumbnailLoader: thumbnailLoader,
                        asset: assetProvider(item.id),
                        transitionNamespace: transitionNamespace,
                        isSelectionMode: selectionMode,
                        isSelected: selectedIDs.contains(item.id),
                        onToggleSelection: { onToggleSelection?(item.id) },
                        onDelete: { onDelete?(item) },
                        onAddToJam: { onAddToJam?([item.id]) },
                        isEntryHidden: isEntryHidden(row: index / 3, participatingRows: participatingRows),
                        reduceMotion: reduceMotion
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, selectionMode && !selectedIDs.isEmpty ? 96 : 8)
        }
        .task(id: entryPresentationID) {
            guard entryPresentationID > 0, entryPresentationID != activeEntryPresentationID else { return }
            activeEntryPresentationID = entryPresentationID
            revealedRowCount = 0
            await Task.yield()
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.15)) { revealedRowCount = participatingRows }
                return
            }
            for row in 1...participatingRows {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { revealedRowCount = row }
                do {
                    try await Task.sleep(for: .milliseconds(55))
                } catch {
                    return
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.grid")
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private func isEntryHidden(row: Int, participatingRows: Int) -> Bool {
        guard row < participatingRows else { return false }
        return entryPresentationID != activeEntryPresentationID || row >= revealedRowCount
    }
}

private struct LibraryGridCell: View {
    let item: StoredPedal
    let calendar: Calendar
    let locale: Locale
    let displayScale: CGFloat
    let imageProvider: LibraryGridImageProvider
    let thumbnailLoader: ThumbnailLoader?
    let asset: PersistedImageAsset?
    let transitionNamespace: Namespace.ID?
    let isSelectionMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    let onAddToJam: () -> Void
    let isEntryHidden: Bool
    let reduceMotion: Bool

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: onToggleSelection) { cellContent }
            } else {
                NavigationLink(value: AppRoute.pedalDetail(item.id)) { cellContent }
            }
        }
        .contextMenu {
            if !isSelectionMode {
                Button(action: onAddToJam) { Label("Add to Jam", systemImage: "plus.circle") }
                if let url = asset?.fileURL {
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSelectionMode && isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 4, style: .continuous))
        .opacity(isEntryHidden ? 0 : 1)
        .scaleEffect(reduceMotion || !isEntryHidden ? 1 : 0.94)
        .offset(y: reduceMotion || !isEntryHidden ? 0 : 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(hasUnavailableCover: loadFailed || (asset == nil && imageProvider(item) == nil)))
        .accessibilityValue(isSelectionMode && isSelected ? "Selected" : "")
        .accessibilityHint(isSelectionMode ? "Toggles selection" : "Opens the photo details")
        .accessibilityAddTraits(isSelectionMode ? .isButton : [])
        .accessibilityAddTraits(isSelectionMode && isSelected ? .isSelected : [])
        .accessibilityIdentifier("library.cell.\(item.id.uuidString)")
    }

    private var cellContent: some View {
        GeometryReader { proxy in
            let targetSize = CGSize(width: proxy.size.width, height: proxy.size.height)
            transitionSource(
                ZStack {
                    if let loadedImage {
                        Image(uiImage: loadedImage).resizable().interpolation(.none).scaledToFill().accessibilityHidden(true)
                    } else if thumbnailLoader == nil || asset == nil || loadFailed {
                        if let fallback = imageProvider(item), !loadFailed {
                            fallback.resizable().interpolation(.none).scaledToFill().accessibilityHidden(true)
                        } else {
                            unavailableCover
                        }
                    } else if let fallback = imageProvider(item) {
                        fallback.resizable().interpolation(.none).scaledToFill().accessibilityHidden(true)
                    } else {
                        ProgressView().tint(.secondary)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            )
            .task(id: targetSize) {
                guard loadedImage == nil, let thumbnailLoader, let asset else { return }
                do {
                    loadedImage = try await thumbnailLoader.loadThumbnail(for: asset, targetSize: targetSize, pixelScale: displayScale)
                } catch is CancellationError {
                } catch {
                    loadFailed = true
                }
            }
        }
    }

    private var unavailableCover: some View {
        ZStack {
            Color.secondary.opacity(0.16)
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func transitionSource<Content: View>(_ content: Content) -> some View {
        if let transitionNamespace {
            content.matchedTransitionSource(id: item.id, in: transitionNamespace)
        } else {
            content
        }
    }

    private func accessibilityLabel(hasUnavailableCover: Bool) -> String {
        let date = item.pedal.createdAt.formattedForLibraryAccessibility(calendar: calendar, locale: locale)
        let name = item.pedal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pitch = item.pedal.dominantPitchClass.accessibilityName
        let cover = hasUnavailableCover ? ", capa indisponível" : ""
        if name.isEmpty { return "Pedal criado em \(date), efeito \(item.pedal.effect.displayName), nota predominante \(pitch)\(cover)" }
        return "Pedal \"\(name)\", criado em \(date), efeito \(item.pedal.effect.displayName), nota predominante \(pitch)\(cover)"
    }
}

private extension Date {
    func formattedForLibraryAccessibility(calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter.string(from: self)
    }
}

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

    @Environment(\.locale) private var locale
    @Environment(\.displayScale) private var displayScale
    @State private var scrollPosition = ScrollPosition(idType: UUID.self)
    @State private var didPerformInitialPositioning = false

    init(
        state: LibraryGridState,
        calendar: Calendar = .current,
        onRetry: (() -> Void)? = nil,
        imageProvider: LibraryGridImageProvider = .persistedCover,
        thumbnailLoader: ThumbnailLoader? = nil,
        assetProvider: @escaping (UUID) -> PersistedImageAsset? = { _ in nil },
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.state = state
        self.calendar = calendar
        self.onRetry = onRetry
        self.imageProvider = imageProvider
        self.thumbnailLoader = thumbnailLoader
        self.assetProvider = assetProvider
        self.transitionNamespace = transitionNamespace
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
        let sections = LibraryProjection.sections(from: pedals, calendar: calendar)
        let recentID = sections.last?.items.last?.id

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(sections) { section in
                    Section {
                        LazyVGrid(columns: gridColumns, spacing: 1) {
                            ForEach(section.items) { item in
                                LibraryGridCell(
                                    item: item,
                                    calendar: calendar,
                                    locale: locale,
                                    displayScale: displayScale,
                                    imageProvider: imageProvider,
                                    thumbnailLoader: thumbnailLoader,
                                    asset: assetProvider(item.id),
                                    transitionNamespace: transitionNamespace
                                )
                            }
                        }
                        .padding(.bottom, 18)
                    } header: {
                        Text(monthTitle(for: section.id))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(.background)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("library.section.\(section.id.year)-\(section.id.month)")
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        .task(id: recentID) {
            guard let recentID, !didPerformInitialPositioning else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            scrollPosition.scrollTo(id: recentID, anchor: .bottom)
            didPerformInitialPositioning = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.grid")
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    }

    private func monthTitle(for yearMonth: YearMonth) -> String {
        guard let date = calendar.date(from: DateComponents(year: yearMonth.year, month: yearMonth.month, day: 1)) else {
            return "\(yearMonth.month)/\(yearMonth.year)"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
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

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        NavigationLink(value: AppRoute.pedalDetail(item.id)) {
            GeometryReader { proxy in
                let targetSize = CGSize(width: proxy.size.width, height: proxy.size.height)
                transitionSource(
                    ZStack {
                        if let loadedImage {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFill()
                                .accessibilityHidden(true)
                        } else if thumbnailLoader == nil || asset == nil || loadFailed {
                            if let fallback = imageProvider(item), !loadFailed {
                                fallback.resizable().interpolation(.none).scaledToFill().accessibilityHidden(true)
                            } else {
                                unavailableCover
                            }
                        } else {
                            ProgressView().tint(.secondary)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                )
                .task(id: targetSize) {
                    guard let thumbnailLoader, let asset else { return }
                    do {
                        loadedImage = try await thumbnailLoader.loadThumbnail(
                            for: asset,
                            targetSize: targetSize,
                            pixelScale: displayScale
                        )
                    } catch is CancellationError {
                    } catch {
                        loadFailed = true
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(hasUnavailableCover: loadFailed || (asset == nil && imageProvider(item) == nil)))
        .accessibilityHint("Abre os detalhes deste pedal")
        .accessibilityIdentifier("library.cell.\(item.id.uuidString)")
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
        let cover = hasUnavailableCover ? ", capa indisponível" : ""
        if name.isEmpty { return "Pedal criado em \(date), efeito \(item.pedal.effect.displayName)\(cover)" }
        return "Pedal \"\(name)\", criado em \(date), efeito \(item.pedal.effect.displayName)\(cover)"
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

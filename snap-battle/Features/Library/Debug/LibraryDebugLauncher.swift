#if DEBUG
import SwiftUI

struct LibraryDebugLauncher: View {
    @State private var dataset: LibraryDebugDataset = .small
    @State private var model: GalleryViewModel
    @State private var unavailableIDs: Set<UUID> = []
    @State private var status = "Nenhum dataset carregado"
    @Namespace private var transitionNamespace

    private let fixtures = LibraryDebugFixtureStore()
    private let thumbnailLoader = ThumbnailLoader()

    init() {
        _model = State(initialValue: GalleryViewModel(store: LibraryDebugFixtureStore().store(for: .small), player: PhotoPedalSynth()))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Dataset") {
                    Picker("Conteúdo", selection: $dataset) {
                        ForEach(LibraryDebugDataset.allCases) { item in Text(item.title).tag(item) }
                    }
                    Button("Carregar dataset", systemImage: "arrow.clockwise") { load(dataset) }
                    Button("Instalar na Library real", systemImage: "arrow.right.circle") { installToRealStore(dataset) }
                    Button("Limpar Library real", systemImage: "trash.circle", role: .destructive) { clearRealStore() }
                    Button("Limpar fixtures debug", systemImage: "trash", role: .destructive) { clear(dataset) }
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Text("Somente DEBUG. Os dados ficam em Application Support/debug-library-fixtures e não compartilham a coleção real. 'Instalar na Library real' copia para a coleção usada pelo app.")
                }
            }
            Divider()
            GalleryView(
                model: model,
                beginCapture: {},
                thumbnailLoader: thumbnailLoader,
                transitionNamespace: transitionNamespace,
                imageProvider: LibraryGridImageProvider { item in
                    unavailableIDs.contains(item.id) ? nil : Image(uiImage: item.cover)
                },
                assetProvider: { id in
                    unavailableIDs.contains(id) ? nil : model.thumbnailAsset(for: id)
                }
            )
        }
        .navigationTitle("Library Debug")
        .onAppear { load(dataset) }
    }

    private func load(_ dataset: LibraryDebugDataset) {
        do {
            let loaded = try fixtures.installAndLoad(dataset)
            unavailableIDs = loaded.unavailableIDs
            model = loaded.model
            status = "\(loaded.loadResult.pedals.count) válidos; \(unavailableIDs.count) capas simuladas indisponíveis; \(loaded.loadResult.issues.count) corrupção isolada"
        } catch {
            status = "Falha ao preparar fixtures: \(error.localizedDescription)"
        }
    }

    private func clear(_ dataset: LibraryDebugDataset) {
        fixtures.reset(dataset: dataset)
        model = GalleryViewModel(store: fixtures.store(for: dataset), player: PhotoPedalSynth())
        model.reload()
        unavailableIDs = []
        status = "Fixtures de \(dataset.title) removidas; dados reais preservados"
    }

    private func installToRealStore(_ dataset: LibraryDebugDataset) {
        do {
            try fixtures.installFixtures(dataset, into: PedalStore.shared)
            status = "\(dataset.count) pedais instalados na Library real"
        } catch {
            status = "Falha ao instalar na Library real: \(error.localizedDescription)"
        }
    }

    private func clearRealStore() {
        let store = PedalStore.shared
        for pedal in store.loadCollection().pedals {
            try? store.delete(id: pedal.id)
        }
        status = "Library real limpa"
    }
}
#endif

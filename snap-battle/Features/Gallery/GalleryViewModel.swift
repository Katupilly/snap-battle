import Observation
import UIKit

@MainActor
@Observable
final class GalleryViewModel {
    enum State {
        case loading
        case empty
        case content([StoredPedal])
        case partialError([StoredPedal], String)
        case blockingError(String)

        var pedals: [StoredPedal] {
            switch self {
            case .content(let pedals), .partialError(let pedals, _): pedals
            case .loading, .empty, .blockingError: []
            }
        }
    }

    var state: State = .loading
    var playbackErrorMessage: String?
    var deletionErrorMessage: String?
    var playingID: UUID?

    private let store: PedalStore
    private let player: any PedalPlaying
    private var thumbnailAssets: [UUID: PersistedImageAsset] = [:]

    convenience init() {
        self.init(store: .shared, player: PhotoPedalSynth())
    }

    init(store: PedalStore, player: any PedalPlaying) {
        self.store = store
        self.player = player
    }

    @discardableResult
    func reload() -> PedalStoreLoadResult {
        state = .loading
        let result = store.loadCollection()
        apply(result)
        return result
    }

    func reloadAsync() async {
        state = .loading
        let store = store
        let runID = PerformanceDiagnostics.makeRunID()
        let result = await Task.detached(priority: .userInitiated) {
            PerformanceDiagnostics.measure("galleryReload", runID: runID) {
                store.loadCollection(diagnosticsRunID: runID)
            }
        }.value
        apply(result)
    }

    private func apply(_ result: PedalStoreLoadResult) {
        thumbnailAssets = store.thumbnailAssets(for: result.pedals)
        if result.pedals.isEmpty {
            state = result.issues.isEmpty ? .empty : .blockingError(result.issues.joined(separator: " "))
        } else {
            state = result.issues.isEmpty ? .content(result.pedals) : .partialError(result.pedals, result.issues.joined(separator: " "))
        }
    }

    func insertedSavedPedal() {
        Task { await reloadAsync() }
    }

    func updateExistingPedal(_ updated: StoredPedal) {
        let current = state.pedals
        guard let index = current.firstIndex(where: { $0.id == updated.id }) else { return }
        var pedals = current
        pedals[index] = updated
        switch state {
        case .content:
            state = .content(pedals)
        case .partialError(_, let message):
            state = .partialError(pedals, message)
        case .loading, .empty, .blockingError:
            break
        }
    }

    func thumbnailAsset(for id: UUID) -> PersistedImageAsset? {
        thumbnailAssets[id]
    }

    func quickPlay(_ item: StoredPedal) {
        do {
            try player.play(item.pedal)
            playingID = item.id
            playbackErrorMessage = nil
        } catch {
            playbackErrorMessage = error.localizedDescription
            playingID = nil
        }
    }

    func playLatest() {
        guard let latest = store.loadLatest() else { return }
        quickPlay(latest)
    }

    @discardableResult
    func delete(_ item: StoredPedal) -> Bool {
        deletionErrorMessage = nil
        if playingID == item.id { player.stop(); playingID = nil }
        do {
            try store.delete(id: item.id)
            reload()
            return true
        } catch {
            deletionErrorMessage = error.localizedDescription
            return false
        }
    }

    func stop(_ item: StoredPedal) {
        guard playingID == item.id else { return }
        player.stop()
        playingID = nil
    }
}

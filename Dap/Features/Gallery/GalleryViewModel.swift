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
    var isSelecting = false
    var selectedIDs: Set<UUID> = []

    private let store: PedalStore
    private let player: any PedalPlaying
    private var thumbnailAssets: [UUID: PersistedImageAsset] = [:]

    convenience init() {
        self.init(store: .shared, player: DapSynth())
    }

    init(store: PedalStore, player: any PedalPlaying) {
        self.store = store
        self.player = player
    }

    @discardableResult
    func reload(reason: GalleryReloadReason = .manual) -> PedalStoreLoadResult {
        state = .loading
        let result = store.loadCollection(reason: reason.rawValue)
        apply(result)
        return result
    }

    func reloadAsync(reason: GalleryReloadReason = .initialLoad) async {
        state = .loading
        let store = store
        let runID = PerformanceDiagnostics.makeRunID()
        let reasonRaw = reason.rawValue
        let result = await Task.detached(priority: .userInitiated) {
            PerformanceDiagnostics.measure("galleryReload", runID: runID) {
                store.loadCollection(diagnosticsRunID: runID, reason: reasonRaw)
            }
        }.value
        apply(result)
    }

    private func apply(_ result: PedalStoreLoadResult) {
        thumbnailAssets = store.thumbnailAssets(for: result.pedals)
        selectedIDs.formIntersection(result.pedals.map(\.id))
        if result.pedals.isEmpty {
            state = result.issues.isEmpty ? .empty : .blockingError(result.issues.joined(separator: " "))
        } else {
            state = result.issues.isEmpty ? .content(result.pedals) : .partialError(result.pedals, result.issues.joined(separator: " "))
        }
    }

    func insertedSavedPedal() {
        Task { await reloadAsync(reason: .saveCompleted) }
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

    func shareURLs(for ids: Set<UUID>) -> [URL] {
        state.pedals.compactMap { ids.contains($0.id) ? thumbnailAssets[$0.id]?.fileURL : nil }
    }

    func beginSelection() {
        isSelecting = true
        selectedIDs.removeAll()
    }

    func cancelSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    func toggleSelection(for id: UUID) {
        guard isSelecting else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
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
        delete(ids: [item.id])
    }

    @discardableResult
    func delete(ids: [UUID]) -> Bool {
        deletionErrorMessage = nil
        for id in ids {
            if playingID == id { player.stop(); playingID = nil }
            do {
                try store.delete(id: id)
            } catch {
                deletionErrorMessage = error.localizedDescription
                reload()
                return false
            }
        }
        selectedIDs.subtract(ids)
        reload()
        return true
    }

    func stop(_ item: StoredPedal) {
        guard playingID == item.id else { return }
        player.stop()
        playingID = nil
    }
}

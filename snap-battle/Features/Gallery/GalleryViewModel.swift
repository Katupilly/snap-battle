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

    convenience init() {
        self.init(store: .shared, player: PhotoPedalSynth())
    }

    init(store: PedalStore, player: any PedalPlaying) {
        self.store = store
        self.player = player
    }

    func reload() {
        state = .loading
        let result = store.loadCollection()
        if result.pedals.isEmpty {
            state = result.issues.isEmpty ? .empty : .blockingError(result.issues.joined(separator: " "))
        } else {
            state = result.issues.isEmpty ? .content(result.pedals) : .partialError(result.pedals, result.issues.joined(separator: " "))
        }
    }

    func insertedSavedPedal() { reload() }

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

    func delete(_ item: StoredPedal) {
        deletionErrorMessage = nil
        if playingID == item.id { player.stop(); playingID = nil }
        do {
            try store.delete(id: item.id)
            reload()
        } catch {
            deletionErrorMessage = error.localizedDescription
        }
    }
}

import Foundation

/// Single visibility source for the custom root navigation. Derived
/// from the current route/presentation state in `AppNavigationModel`
/// — never stored independently.
enum RootNavigationVisibility: Equatable {
    case visible
    case hidden
}

/// Root-navigation state, separated from the contextual bar's
/// contract so the app shell can own the persistent Gallery/Jam
/// roots while Capture keeps using the contextual flow.
struct RootNavigationState: Equatable {
    /// The persistent roots, in tab order. Static: the set of roots
    /// is a product contract, not per-screen state.
    static let destinations: [RootDestination] = [.gallery, .jam]

    var selectedDestination: RootDestination
    var visibility: RootNavigationVisibility
}

/// Visual availability for the custom root chrome.
struct RootChromePresentation: Equatable {
    let shouldShowTab: Bool
    let shouldShowCapture: Bool

    init(rootNavigation: RootNavigationState, galleryBottomChromeMode: GalleryBottomChromeMode = .navigation) {
        let gallerySelectionChromeIsActive = rootNavigation.selectedDestination == .gallery
            && galleryBottomChromeMode != .navigation
        shouldShowTab = rootNavigation.visibility == .visible && !gallerySelectionChromeIsActive
        shouldShowCapture = shouldShowTab
    }
}

enum GalleryBottomChromeMode: Equatable {
    case navigation
    case selectingEmpty
    case selecting(count: Int)

    init(isSelecting: Bool, selectedCount: Int) {
        if !isSelecting {
            self = .navigation
        } else if selectedCount == 0 {
            self = .selectingEmpty
        } else {
            self = .selecting(count: selectedCount)
        }
    }
}

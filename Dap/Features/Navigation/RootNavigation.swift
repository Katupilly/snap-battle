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

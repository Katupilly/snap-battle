import Foundation

/// Single visibility source shared by the native tab bar and the
/// `CaptureTabAccessory`. Derived from the current
/// route/presentation state in `AppNavigationModel` — never stored
/// independently. Product rule: root navigation visible → tab bar
/// and accessory visible; root navigation hidden → both hidden.
enum RootNavigationVisibility: Equatable {
    case visible
    case hidden
}

/// Root-navigation state, separated from the contextual bar's
/// contract so Increment 2 can replace the root-navigation portion
/// (custom bar → native `TabView`) without touching the contextual
/// portion. The legacy `BottomBarPresentation.forNavigation` keeps
/// driving the current bar for now.
struct RootNavigationState: Equatable {
    /// The persistent roots, in tab order. Static: the set of roots
    /// is a product contract, not per-screen state.
    static let destinations: [RootDestination] = [.gallery, .jam]

    var selectedDestination: RootDestination
    var visibility: RootNavigationVisibility
}

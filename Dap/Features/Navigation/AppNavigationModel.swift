import Observation
import Foundation

enum GalleryRoute: Hashable {
    case inspector(UUID)
}

enum JamRoute: Hashable {
    case pedalboardDetail(UUID)
}

enum AppTab: Hashable {
    case gallery
    case jam
}

@MainActor
@Observable
final class AppNavigationModel {
    typealias Destination = AppTab

    var selectedDestination: Destination = .gallery
    var galleryPath: [GalleryRoute] = []
    var jamPath: [JamRoute] = []
    var isPresentingCapture = false
    private(set) var destinationBeforeCapture: Destination = .gallery

    func beginCapture() {
        destinationBeforeCapture = selectedDestination
        isPresentingCapture = true
    }

    func cancelCapture() {
        isPresentingCapture = false
        selectedDestination = destinationBeforeCapture
    }

    func completeCapture() {
        isPresentingCapture = false
        galleryPath.removeAll()
        selectedDestination = .gallery
    }

    func openPedalboard(id: Pedalboard.ID) {
        selectedDestination = .jam
        jamPath.append(.pedalboardDetail(id))
    }

    func openInspector(id: UUID) {
        selectedDestination = .gallery
        galleryPath = [.inspector(id)]
    }

    var isShowingRootDetail: Bool {
        switch selectedDestination {
        case .gallery:
            !galleryPath.isEmpty
        case .jam:
            !jamPath.isEmpty
        }
    }

    /// Single visibility source for root navigation, derived from
    /// the current route/presentation. Reading this never changes
    /// selection, path, or presentation state.
    var rootNavigation: RootNavigationState {
        RootNavigationState(
            selectedDestination: RootDestination(selectedDestination) ?? .gallery,
            visibility: (isShowingRootDetail || isPresentingCapture) ? .hidden : .visible
        )
    }
}

enum RootDestination: Hashable, Identifiable {
    case gallery
    case jam

    var id: Self { self }
    var title: String {
        switch self {
        case .gallery: "Gallery"
        case .jam: "Jam"
        }
    }

    var systemImage: String {
        switch self {
        case .gallery: "square.grid.2x2"
        case .jam: "music.note.list"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .gallery: "bottomBar.destination.gallery"
        case .jam: "bottomBar.destination.jam"
        }
    }

    init?(_ destination: AppNavigationModel.Destination) {
        switch destination {
        case .gallery:
            self = .gallery
        case .jam:
            self = .jam
        }
    }

    var appDestination: AppNavigationModel.Destination {
        switch self {
        case .gallery: .gallery
        case .jam: .jam
        }
    }
}

enum BottomBarActionRole: Equatable {
    case normal
    case cancel
    case destructive
}

struct BottomBarAction: Equatable, Identifiable {
    enum ID: Hashable {
        case capture
        case openCamera
        case cancel
        case tryAgain
        case discard
        case retake
        case savePedal
    }

    let id: ID
    let title: String
    let systemImage: String
    var role: BottomBarActionRole = .normal
    var isEnabled = true
    var isLoading = false
    var accessibilityLabel: String? = nil
    var accessibilityHint: String? = nil
}

struct NavigationBarConfiguration: Equatable {
    var destinations: [RootDestination]
    var selectedDestination: RootDestination?
    var captureAction: BottomBarAction?
}

struct ContextualBarConfiguration: Equatable {
    var primaryAction: BottomBarAction?
    var secondaryAction: BottomBarAction?
}

enum BottomBarHiddenReason: Equatable {
    case camera
    case processing
    case pedalDetail
    case unavailable
}

enum BottomBarPresentation: Equatable {
    case navigation(NavigationBarConfiguration)
    case contextual(ContextualBarConfiguration)
    case hidden(BottomBarHiddenReason)

    static func root(selected destination: AppNavigationModel.Destination) -> Self {
        return .navigation(
            NavigationBarConfiguration(
                destinations: [.gallery, .jam],
                selectedDestination: RootDestination(destination),
                captureAction: .capture
            )
        )
    }

    static func forNavigation(_ navigation: AppNavigationModel) -> Self {
        if navigation.isShowingRootDetail { return .hidden(.pedalDetail) }
        return .root(selected: navigation.selectedDestination)
    }

    static func captureFlow(
        _ phase: CaptureFlowPhase,
        canCompleteResult: Bool = true,
        isCompletingResult: Bool = false
    ) -> Self {
        switch phase {
        case .picker:
            .contextual(
                ContextualBarConfiguration(
                    primaryAction: .openCamera,
                    secondaryAction: .cancel
                )
            )
        case .processing:
            .hidden(.processing)
        case .saveRetry:
            .contextual(
                ContextualBarConfiguration(
                    primaryAction: .tryAgain,
                    secondaryAction: .discard
                )
            )
        case .result:
            .contextual(
                ContextualBarConfiguration(
                    primaryAction: BottomBarAction.savePedal.configured(
                        isEnabled: canCompleteResult,
                        isLoading: isCompletingResult
                    ),
                    secondaryAction: .retake
                )
            )
        case .camera:
            .hidden(.camera)
        }
    }
}

enum CaptureFlowPhase: Equatable {
    case picker
    case processing
    case saveRetry
    case result
    case camera
}

extension BottomBarAction {
    func configured(isEnabled: Bool, isLoading: Bool = false) -> Self {
        var copy = self
        copy.isEnabled = isEnabled
        copy.isLoading = isLoading
        return copy
    }

    static let capture = BottomBarAction(
        id: .capture,
        title: "Capture",
        systemImage: "camera.fill",
        accessibilityLabel: "Capture pedal",
        accessibilityHint: "Opens capture to create a new pedal"
    )

    static let openCamera = BottomBarAction(
        id: .openCamera,
        title: "Open Camera",
        systemImage: "camera.fill",
        accessibilityLabel: "Open camera",
        accessibilityHint: "Opens the camera to capture a new pedal photo"
    )

    static let cancel = BottomBarAction(
        id: .cancel,
        title: "Cancel",
        systemImage: "xmark",
        role: .cancel,
        accessibilityLabel: "Cancel capture",
        accessibilityHint: "Closes capture and returns to the previous screen"
    )

    static let tryAgain = BottomBarAction(
        id: .tryAgain,
        title: "Try Again",
        systemImage: "arrow.clockwise",
        accessibilityLabel: "Try saving again",
        accessibilityHint: "Attempts to save this pedal again"
    )

    static let discard = BottomBarAction(
        id: .discard,
        title: "Discard",
        systemImage: "trash",
        role: .destructive,
        accessibilityLabel: "Discard result",
        accessibilityHint: "Discards this unsaved result and closes capture"
    )

    static let retake = BottomBarAction(
        id: .retake,
        title: "Retake",
        systemImage: "camera.rotate",
        role: .cancel,
        accessibilityLabel: "Retake photo",
        accessibilityHint: "Returns to capture without deleting any saved pedal"
    )

    static let savePedal = BottomBarAction(
        id: .savePedal,
        title: "Save Pedal",
        systemImage: "checkmark",
        accessibilityLabel: "Save pedal",
        accessibilityHint: "Completes this pedal and shows it in Gallery"
    )
}

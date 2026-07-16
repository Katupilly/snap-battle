import Observation

@MainActor
@Observable
final class AppNavigationModel {
    enum Destination: Hashable { case gallery, jam }

    var selectedDestination: Destination = .gallery
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
        selectedDestination = .gallery
    }
}

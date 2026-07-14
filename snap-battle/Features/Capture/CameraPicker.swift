import AVFoundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CameraCaptureModel: NSObject, AVCapturePhotoCaptureDelegate {
    @ObservationIgnored nonisolated(unsafe) let session = AVCaptureSession()
    var isAuthorized = false
    var isConfigured = false
    var isRunning = false
    var errorMessage: String?
    @ObservationIgnored nonisolated(unsafe) private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "snap-battle.camera")
    private var continuation: CheckedContinuation<UIImage?, Never>?

    func configure() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let authorized: Bool
        if status == .authorized { authorized = true }
        else if status == .notDetermined { authorized = await AVCaptureDevice.requestAccess(for: .video) }
        else { authorized = false }
        isAuthorized = authorized
        guard authorized else {
            errorMessage = "Camera permission was denied."
            return
        }
        guard !isConfigured else { return }
        let configured = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            queue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                defer { self.session.commitConfiguration() }
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                    continuation.resume(returning: false)
                    return
                }
                self.session.addInput(input)
                self.session.addOutput(self.output)
                continuation.resume(returning: true)
            }
        }
        isConfigured = configured
        if !configured { errorMessage = "Camera could not be configured." }
    }

    func start() {
        guard isConfigured, !isRunning else { return }
        isRunning = true
        queue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        queue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capture() async -> UIImage? {
        guard isConfigured else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in self.continuation?.resume(returning: image); self.continuation = nil }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { let view = PreviewView(); view.previewLayer.session = session; view.previewLayer.videoGravity = .resizeAspectFill; return view }
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

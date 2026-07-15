import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var model: CaptureViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var loadingImage = false
    @State private var loadError: String?
    @State private var battleCreature: Creature?
    @State private var showingBattle = false

    init() {
        #if DEBUG
        let generator: any CreatureGenerating = ProcessInfo.processInfo.arguments.contains("--mock-generator") ? MockCreatureGenerator() : FoundationModelsCreatureGenerator()
        _model = State(initialValue: CaptureViewModel(generator: generator))
        #else
        _model = State(initialValue: CaptureViewModel())
        #endif
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result = model.result {
                    CreatureResultView(creature: result, reset: model.reset, onBattle: { battleCreature = result; showingBattle = true })
                } else {
                    CaptureView(model: model, selectedItem: $selectedItem, showingCamera: $showingCamera, loadingImage: $loadingImage, loadError: $loadError)
                }
            }
            .navigationTitle("Snap Battle")
            .sheet(isPresented: $showingCamera) {
                CameraScreen { image in
                    showingCamera = false
                    model.process(image)
                }
            }
            .navigationDestination(isPresented: $showingBattle) {
                if let battleCreature {
                    BattleView(player: battleCreature)
                } else {
                    EmptyView()
                }
            }
            .onAppear { model.refreshEnvironmentDiagnostics() }
        }
    }
}

struct CaptureView: View {
    let model: CaptureViewModel
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var showingCamera: Bool
    @Binding var loadingImage: Bool
    @Binding var loadError: String?

    var body: some View {
        let isProcessing = if case .processing = model.state { true } else { false }

        VStack(spacing: 28) {
            Spacer(minLength: 12)
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Capture a creature")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Frame it clearly and let the battle begin.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            if !isProcessing {
                VStack(spacing: 12) {
                    Button { showingCamera = true } label: {
                        Label("Open camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint("Opens the camera to capture the creature")

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose from photos", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .frame(maxWidth: 360)
            }

            #if DEBUG
            NavigationLink {
                BattleDebugLauncher()
            } label: {
                Label("Battle Debug", systemImage: "hammer")
            }
            .buttonStyle(.bordered)
            #endif

            if case .processing(let stage) = model.state {
                CreatureGenerationView(stage: stage, cancel: model.cancel)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if case .failed = model.state {
                CaptureErrorView {
                    loadError = nil
                    model.reset()
                }
            } else if loadError != nil {
                CaptureErrorView(message: "Não foi possível carregar essa imagem.") {
                    loadError = nil
                }
            }

            if loadingImage {
                ProgressView("Preparing photo…")
                    .accessibilityLabel("Preparing selected photo")
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: model.state)
        .task(id: selectedItem) { await loadSelectedPhoto() }
    }

    private func loadSelectedPhoto() async {
        guard let selectedItem else { return }
        loadingImage = true
        defer { loadingImage = false }
        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw AppError.imageDecodeFailed }
            model.process(image)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct CaptureErrorView: View {
    var message = "A criatura não conseguiu ser formada."
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            Text("Tente uma foto mais nítida e mantenha a criatura inteira no enquadramento.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.thinMaterial, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct CameraScreen: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera = CameraCaptureModel()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreview(session: camera.session).ignoresSafeArea()
                CaptureFrameGuide()
                    .padding(.horizontal, 34)
                    .padding(.vertical, 132)
                    .accessibilityHidden(true)
            } else {
                CameraUnavailableView(message: camera.errorMessage)
            }

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Snap Battle")
                            .font(.headline.weight(.bold))
                        Text(isCapturing ? "Saving your snapshot…" : "Keep the creature in frame")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.white)
                        .accessibilityLabel("Close camera")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                if isCapturing {
                    ProgressView()
                        .tint(.white)
                        .padding(.bottom, 18)
                        .accessibilityLabel("Capturing photo")
                }

                Button {
                    guard !isCapturing else { return }
                    Task {
                        isCapturing = true
                        defer { isCapturing = false }
                        if let image = await camera.capture() {
                            camera.stop()
                            onCapture(image)
                        }
                    }
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 6).padding(4))
                }
                .buttonStyle(CameraShutterButtonStyle(reduceMotion: reduceMotion))
                .disabled(isCapturing || !camera.isConfigured)
                .accessibilityLabel(isCapturing ? "Capturing photo" : "Take photo")
                .accessibilityHint("Captures the creature and starts the analysis")
                .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.85), trigger: isCapturing)
                .padding(.bottom, 28)
            }
            .padding(.bottom, 8)
        }
        .background(.black)
        .task { await camera.configure(); camera.start() }
        .onDisappear { camera.stop() }
    }
}

private struct CameraUnavailableView: View {
    let message: String?

    var body: some View {
        ContentUnavailableView("Camera unavailable", systemImage: "video.slash.fill", description: Text(message ?? "Allow camera access to continue."))
            .foregroundStyle(.white)
    }
}

private struct CaptureFrameGuide: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 2, dash: [14, 10]))
            .overlay(alignment: .bottom) {
                Text("Center the creature")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.38), in: Capsule())
                    .padding(.bottom, 16)
            }
    }
}

private struct CameraShutterButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

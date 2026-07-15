import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var model = PhotoPedalViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        NavigationStack {
            Group {
                if let pedal = model.pedal, let cover = model.cover {
                    PedalResultView(model: model, pedal: pedal, cover: cover)
                } else {
                    PedalCaptureView(model: model, selectedItem: $selectedItem, showingCamera: $showingCamera)
                }
            }
            .navigationTitle("Photo Pedal")
            .sheet(isPresented: $showingCamera) {
                CameraScreen { image in
                    showingCamera = false
                    model.process(image)
                }
            }
            .onChange(of: selectedItem) {
                guard let selectedItem else { return }
                Task { model.load(data: try? await selectedItem.loadTransferable(type: Data.self)) }
            }
            .onChange(of: AppIntentRouter.shared.request, initial: true) { _, request in
                guard let request else { return }
                switch request {
                case .create:
                    model.reset()
                    showingCamera = true
                case .playLast: model.playLast()
                }
                AppIntentRouter.shared.request = nil
            }
        }
    }
}

private struct PedalCaptureView: View {
    let model: PhotoPedalViewModel
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var showingCamera: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.metering.matrix")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("Transforme uma foto em som")
                    .font(.title2.bold())
                Text("A imagem vira uma capa 2-bit, uma sequência chiptune e um pedal único.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if model.isProcessing { ProgressView(model.stage.rawValue).padding() }
            else {
                Button("Abrir câmera", systemImage: "camera.fill") { showingCamera = true }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Escolher foto", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
            Spacer()
        }
        .padding(24)
    }
}

struct CameraScreen: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraCaptureModel()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            if camera.isAuthorized { CameraPreview(session: camera.session).ignoresSafeArea() }
            else { ContentUnavailableView("Câmera indisponível", systemImage: "video.slash", description: Text(camera.errorMessage ?? "Permita o acesso à câmera.")) }
            VStack {
                HStack {
                    VStack(alignment: .leading) { Text("Photo Pedal").font(.headline.bold()); Text("Enquadre uma textura ou cena").font(.subheadline) }
                    .foregroundStyle(.white)
                    Spacer()
                    Button("Fechar", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).foregroundStyle(.white)
                }
                Spacer()
                Button {
                    Task { isCapturing = true; defer { isCapturing = false }; if let image = await camera.capture() { camera.stop(); onCapture(image) } }
                } label: { Circle().fill(.white).frame(width: 76, height: 76).overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 6).padding(4)) }
                .disabled(isCapturing || !camera.isConfigured).padding(.bottom, 28)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .background(.black)
        .task { await camera.configure(); camera.start() }
        .onDisappear { camera.stop() }
    }
}

import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var navigation = AppNavigationModel()
    @State private var gallery = GalleryViewModel()

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack {
            Group {
                switch navigation.selectedDestination {
                case .gallery: GalleryView(model: gallery, beginCapture: navigation.beginCapture)
                case .jam: JamPlaceholderView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                MainNavigationBar(selected: $navigation.selectedDestination, beginCapture: navigation.beginCapture)
            }
        }
        .task { await gallery.reloadAsync() }
        .sheet(isPresented: $navigation.isPresentingCapture, onDismiss: { gallery.insertedSavedPedal() }) {
            CaptureFlowView(
                onCancel: navigation.cancelCapture,
                onComplete: {
                    navigation.completeCapture()
                    gallery.insertedSavedPedal()
                },
                onMetadataUpdate: { gallery.updateExistingPedal($0) }
            )
        }
        .onChange(of: AppIntentRouter.shared.request, initial: true) { _, request in
            guard let request else { return }
            switch request {
            case .create: navigation.beginCapture()
            case .playLast: gallery.playLatest()
            }
            AppIntentRouter.shared.request = nil
        }
    }
}

private struct MainNavigationBar: View {
    @Binding var selected: AppNavigationModel.Destination
    let beginCapture: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            destinationButton(.gallery, title: "Gallery", symbol: "square.grid.2x2")
            Button(action: beginCapture) {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.title3.weight(.semibold))
                    Text("Criar")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                    .frame(minWidth: 64, minHeight: 56)
                    .padding(.horizontal, 4)
                    .background(.tint, in: .rect(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("Criar pedal")
            .accessibilityHint("Abre a câmera ou a biblioteca de fotos para criar um pedal")
            destinationButton(.jam, title: "Jam", symbol: "music.note.list")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navegação principal")
    }

    private func destinationButton(_ destination: AppNavigationModel.Destination, title: String, symbol: String) -> some View {
        Button { selected = destination } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.headline.weight(selected == destination ? .semibold : .regular))
                Text(title)
                    .font(.caption.weight(selected == destination ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
                .foregroundStyle(selected == destination ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(.rect)
        }
        .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(title)
        .accessibilityHint("Mostra \(title)")
        .accessibilityAddTraits(selected == destination ? [.isSelected] : [])
    }
}

struct PressFeedbackButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CaptureFlowView: View {
    let onCancel: () -> Void
    let onComplete: () -> Void
    @State private var model: PhotoPedalViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @Environment(\.dismiss) private var dismiss

    init(onCancel: @escaping () -> Void, onComplete: @escaping () -> Void, onMetadataUpdate: @escaping (StoredPedal) -> Void) {
        self.onCancel = onCancel
        self.onComplete = onComplete
        _model = State(initialValue: PhotoPedalViewModel(metadataUpdateHandler: onMetadataUpdate))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pedal = model.pedal, let cover = model.cover {
                    PedalResultView(model: model, pedal: pedal, cover: cover, onDone: {
                        onComplete()
                        dismiss()
                    })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fechar") { dismiss() }
                        }
                    }
                } else if model.pendingPedal != nil, model.pendingCover != nil {
                    SaveRetryView(model: model, cancel: onCancel)
                } else {
                    PedalCaptureView(model: model, selectedItem: $selectedItem, showingCamera: $showingCamera, cancel: onCancel)
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
                let runID = PerformanceDiagnostics.makeRunID()
                PerformanceDiagnostics.signpostEvent("pickerSelection", runID: runID, details: "executor=main")
                Task {
                    let data = try? await PerformanceDiagnostics.measure("pickerTransfer", runID: runID) {
                        try await selectedItem.loadTransferable(type: Data.self)
                    }
                    PerformanceDiagnostics.event("pickerTransferCompleted", runID: runID, details: "dataBytes=\(data?.count ?? 0)")
                    model.load(data: data, runID: runID)
                }
            }
        }
    }
}

private struct PedalCaptureView: View {
    let model: PhotoPedalViewModel
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var showingCamera: Bool
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.metering.matrix").font(.system(size: 58, weight: .medium)).foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("Transforme uma foto em som").font(.title2.bold())
                Text("A imagem vira uma capa 2-bit, uma sequência chiptune e um pedal único.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if model.isProcessing { ProgressView(model.stage.rawValue).padding().accessibilityLabel(model.stage.rawValue) }
            else {
                Button("Abrir câmera", systemImage: "camera.fill") { showingCamera = true }.buttonStyle(.borderedProminent).controlSize(.large)
                PhotosPicker(selection: $selectedItem, matching: .images) { Label("Escolher foto", systemImage: "photo.on.rectangle") }
                    .buttonStyle(.bordered).controlSize(.large)
                Button("Cancelar", action: cancel).buttonStyle(.borderless)
            }
            if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
            Spacer()
        }
        .padding(24)
    }
}

private struct SaveRetryView: View {
    let model: PhotoPedalViewModel
    let cancel: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Pedal pronto para salvar", systemImage: "exclamationmark.triangle")
        } description: {
            Text(model.saveErrorMessage ?? "Não foi possível salvar este pedal.")
        } actions: {
            Button("Tentar salvar") { model.retrySave() }.buttonStyle(.borderedProminent)
            Button("Descartar resultado", role: .destructive) { model.discardPendingResult(); cancel() }
        }
        .accessibilityElement(children: .contain)
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
                    VStack(alignment: .leading) { Text("Photo Pedal").font(.headline.bold()); Text("Enquadre uma textura ou cena").font(.subheadline) }.foregroundStyle(.white)
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

import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var navigation = AppNavigationModel()
    @State private var gallery = GalleryViewModel()
    @Namespace private var bottomBarNamespace

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
                ContextualBottomBar(
                    presentation: .root(selected: navigation.selectedDestination),
                    namespace: bottomBarNamespace,
                    perform: { action in
                        switch action {
                        case .capture:
                            navigation.beginCapture()
                        default:
                            break
                        }
                    },
                    selectDestination: { destination in
                        navigation.selectedDestination = destination.appDestination
                    }
                )
            }
        }
        .task { await gallery.reloadAsync() }
        .sheet(isPresented: $navigation.isPresentingCapture, onDismiss: { gallery.insertedSavedPedal() }) {
            CaptureFlowView(
                bottomBarNamespace: bottomBarNamespace,
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

private struct ContextualBottomBar: View {
    let presentation: BottomBarPresentation
    let namespace: Namespace.ID
    let perform: (BottomBarAction.ID) -> Void
    var selectDestination: (RootDestination) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82), value: presentation)
    }

    @ViewBuilder
    private var content: some View {
        switch presentation {
        case .navigation(let configuration):
            visibleBar(modeIdentifier: "bottomBar.mode.navigation", label: "Navegação principal") {
                HStack(alignment: .center, spacing: 14) {
                    largeNavigationPiece(configuration)
                    if let captureAction = configuration.captureAction {
                        smallActionPiece(captureAction)
                    }
                }
            }
        case .contextual(let configuration):
            visibleBar(modeIdentifier: "bottomBar.mode.contextual", label: "Ações contextuais") {
                HStack(alignment: .center, spacing: 14) {
                    if let secondary = configuration.secondaryAction {
                        smallActionPiece(secondary)
                    }
                    if let primary = configuration.primaryAction {
                        largeActionPiece(primary)
                    }
                }
            }
        case .hidden:
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
                .accessibilityIdentifier("bottomBar.mode.hidden")
        }
    }

    private func visibleBar<Content: View>(
        modeIdentifier: String,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(.bar)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityIdentifier(modeIdentifier)
    }

    private func largeNavigationPiece(_ configuration: NavigationBarConfiguration) -> some View {
        HStack(spacing: 8) {
            ForEach(configuration.destinations) { destination in
                Button {
                    selectDestination(destination)
                } label: {
                    Label(destination.title, systemImage: destination.systemImage)
                        .font(.subheadline.weight(configuration.selectedDestination == destination ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
                .foregroundStyle(configuration.selectedDestination == destination ? Color.accentColor : Color.primary)
                .accessibilityLabel(destination.title)
                .accessibilityHint("Shows \(destination.title)")
                .accessibilityAddTraits(configuration.selectedDestination == destination ? [.isSelected] : [])
                .accessibilityIdentifier(destination.accessibilityIdentifier)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .matchedGeometryEffect(id: "large-piece", in: namespace)
        .accessibilityIdentifier("bottomBar.root")
    }

    private func largeActionPiece(_ action: BottomBarAction) -> some View {
        actionButton(action)
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accentColor, in: .rect(cornerRadius: 22, style: .continuous))
            .foregroundStyle(.white)
            .matchedGeometryEffect(id: "large-piece", in: namespace)
            .accessibilityIdentifier("bottomBar.action.primary")
    }

    private func smallActionPiece(_ action: BottomBarAction) -> some View {
        actionButton(action)
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: action.id == .capture ? 56 : 92)
            .frame(height: 56)
            .padding(.horizontal, 8)
            .background(action.role == .destructive ? Color.red.opacity(0.16) : Color.primary.opacity(0.08), in: .rect(cornerRadius: 22, style: .continuous))
            .foregroundStyle(action.role == .destructive ? Color.red : Color.primary)
            .matchedGeometryEffect(id: "small-piece", in: namespace)
            .accessibilityIdentifier("bottomBar.action.secondary")
    }

    private func actionButton(_ action: BottomBarAction) -> some View {
        Button(role: action.role.buttonRole) {
            perform(action.id)
        } label: {
            HStack(spacing: 8) {
                if action.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: action.systemImage)
                        .accessibilityHidden(true)
                }
                Text(action.title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
        .disabled(!action.isEnabled || action.isLoading)
        .accessibilityLabel(action.accessibilityLabel ?? action.title)
        .accessibilityHint(action.accessibilityHint ?? "")
        .accessibilityIdentifier(identifier(for: action, fallback: "bottomBar.action.\(action.id)"))
    }

    private func identifier(for action: BottomBarAction, fallback: String) -> String {
        switch action.id {
        case .capture: "bottomBar.action.capture"
        case .savePedal: "bottomBar.action.savePedal"
        case .retake: "bottomBar.action.retake"
        default: fallback
        }
    }
}

private extension BottomBarActionRole {
    var buttonRole: ButtonRole? {
        switch self {
        case .normal:
            nil
        case .cancel:
            .cancel
        case .destructive:
            .destructive
        }
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
    let bottomBarNamespace: Namespace.ID
    let onCancel: () -> Void
    let onComplete: () -> Void
    @State private var model: PhotoPedalViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @Environment(\.dismiss) private var dismiss

    init(
        bottomBarNamespace: Namespace.ID,
        onCancel: @escaping () -> Void,
        onComplete: @escaping () -> Void,
        onMetadataUpdate: @escaping (StoredPedal) -> Void
    ) {
        self.bottomBarNamespace = bottomBarNamespace
        self.onCancel = onCancel
        self.onComplete = onComplete
        _model = State(initialValue: PhotoPedalViewModel(metadataUpdateHandler: onMetadataUpdate))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pedal = model.pedal, let cover = model.cover {
                    PedalResultView(model: model, pedal: pedal, cover: cover)
                } else if model.pendingPedal != nil, model.pendingCover != nil {
                    SaveRetryView(model: model)
                } else {
                    PedalCaptureView(model: model, selectedItem: $selectedItem)
                }
            }
            .navigationTitle("Photo Pedal")
            .safeAreaInset(edge: .bottom) {
                ContextualBottomBar(
                    presentation: BottomBarPresentation.captureFlow(phase),
                    namespace: bottomBarNamespace,
                    perform: handleBottomBarAction
                )
            }
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

    private var phase: CaptureFlowPhase {
        if showingCamera { return .camera }
        if model.pedal != nil, model.cover != nil { return .result }
        if model.pendingPedal != nil, model.pendingCover != nil { return .saveRetry }
        if model.isProcessing { return .processing }
        return .picker
    }

    private func handleBottomBarAction(_ action: BottomBarAction.ID) {
        switch action {
        case .openCamera:
            showingCamera = true
        case .cancel:
            onCancel()
        case .tryAgain:
            model.retrySave()
        case .discard:
            model.discardPendingResult()
            onCancel()
        case .retake:
            selectedItem = nil
            showingCamera = false
            model.reset()
        case .savePedal:
            guard model.pedal != nil, model.cover != nil else { return }
            onComplete()
            dismiss()
        case .capture:
            break
        }
    }
}

private struct PedalCaptureView: View {
    let model: PhotoPedalViewModel
    @Binding var selectedItem: PhotosPickerItem?

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
                PhotosPicker(selection: $selectedItem, matching: .images) { Label("Escolher foto", systemImage: "photo.on.rectangle") }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
            Spacer()
        }
        .padding(24)
    }
}

private struct SaveRetryView: View {
    let model: PhotoPedalViewModel

    var body: some View {
        ContentUnavailableView {
            Label("Pedal pronto para salvar", systemImage: "exclamationmark.triangle")
        } description: {
            Text(model.saveErrorMessage ?? "Não foi possível salvar este pedal.")
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
                .disabled(isCapturing || !camera.isConfigured)
                .accessibilityLabel("Capture photo")
                .accessibilityHint("Takes a photo to create a pedal")
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .background(.black)
        .task { await camera.configure(); camera.start() }
        .onDisappear { camera.stop() }
    }
}

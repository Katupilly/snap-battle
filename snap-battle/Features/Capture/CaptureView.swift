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
                    #if DEBUG
                    CreatureResultView(creature: result, reset: model.reset, onBattle: { battleCreature = result; showingBattle = true }, diagnostics: model.diagnostics, runAgain: model.runAgainWithSameImage, isRepeating: model.isRepeating)
                    #else
                    CreatureResultView(creature: result, reset: model.reset, onBattle: { battleCreature = result; showingBattle = true })
                    #endif
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
        VStack(spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack").font(.system(size: 64)).foregroundStyle(.tint)
            Text("Turn a photo into a creature").font(.title2.weight(.semibold)).multilineTextAlignment(.center)
            Text("The image is analyzed on-device. Numeric stats are deterministic.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button { showingCamera = true } label: { Label("Camera", systemImage: "camera") }.buttonStyle(.borderedProminent)
                PhotosPicker(selection: $selectedItem, matching: .images) { Label("Choose photo", systemImage: "photo") }.buttonStyle(.bordered)
            }
            #if DEBUG
            NavigationLink {
                BattleDebugLauncher()
            } label: {
                Label("Battle Debug", systemImage: "hammer")
            }
            .buttonStyle(.bordered)
            #endif
            if case .processing(let stage) = model.state { CreatureGenerationView(stage: stage, cancel: model.cancel) }
            if case .failed(let error) = model.state { Text(error.localizedDescription).foregroundStyle(.red).multilineTextAlignment(.center) }
            if loadingImage { ProgressView("Loading photo…") }
        }
        .padding()
        .task(id: selectedItem) { await loadSelectedPhoto() }
    }

    private func loadSelectedPhoto() async {
        guard let selectedItem else { return }
        loadingImage = true
        defer { loadingImage = false }
        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw AppError.imageDecodeFailed }
            model.process(image)
        } catch { loadError = error.localizedDescription }
    }
}

struct CameraScreen: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraCaptureModel()
    @State private var isCapturing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if camera.isAuthorized { CameraPreview(session: camera.session).ignoresSafeArea() }
            else { ContentUnavailableView("Camera unavailable", systemImage: "video.slash.fill", description: Text(camera.errorMessage ?? "Allow camera access to continue.")) }
            VStack {
                HStack { Spacer(); Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).padding().background(.ultraThinMaterial, in: Circle()) }
                Spacer()
                if isCapturing { ProgressView().tint(.white).padding() }
                Button {
                    Task { isCapturing = true; if let image = await camera.capture() { camera.stop(); onCapture(image) }; isCapturing = false }
                } label: { Circle().fill(.white).frame(width: 74, height: 74).overlay(Circle().stroke(.gray, lineWidth: 3)) }
                .disabled(isCapturing || !camera.isConfigured)
                .padding(.bottom, 24)
            }.padding()
        }
        .task { await camera.configure(); camera.start() }
        .onDisappear { camera.stop() }
    }
}

struct ScanningOverlay<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        content().overlay {
            TimelineView(.animation) { timeline in
                GeometryReader { proxy in
                    let position = proxy.size.height * (0.5 + 0.45 * sin(timeline.date.timeIntervalSinceReferenceDate * 2.2))
                    Rectangle().fill(.tint.opacity(0.7)).frame(height: 2).shadow(color: Color.accentColor, radius: 6).position(x: proxy.size.width / 2, y: position)
                }
            }
        }.clipShape(.rect(cornerRadius: 12))
    }
}

#if DEBUG
struct DebugDiagnosticsView: View {
    let diagnostics: DebugDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug diagnostics").font(.headline)
            Text("Generator: \(diagnostics.activeGenerator.rawValue)")
            Text("Model state: \(diagnostics.modelAvailability.state.rawValue)")
            Text("Model detail: \(diagnostics.modelAvailability.detail)")
            Text("Locale: \(diagnostics.modelAvailability.currentLocale) (\(diagnostics.modelAvailability.currentLocaleSupported ? "supported" : "unsupported"))")
            Text("Model languages: \(diagnostics.modelAvailability.supportedLanguages.joined(separator: ", "))")
            Text("Camera: \(diagnostics.cameraAvailable ? "available" : "unavailable")")
            Text("Subject extraction: \(diagnostics.subjectExtractionAvailable ? "available" : "unavailable")")
            if let run = diagnostics.currentRun { RunDiagnosticsView(run: run) }
            if let first = diagnostics.firstRun, let second = diagnostics.repeatedRun {
                Divider()
                RunComparisonView(first: first, second: second)
            }
        }
        .font(.caption2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }
}

private struct RunDiagnosticsView: View {
    let run: DiagnosticRun

    var body: some View {
        Group {
            Text("Run: \(run.id)")
            if !run.fingerprint.isEmpty { Text("Fingerprint: \(run.fingerprint.prefix(12))…") }
            if let size = run.originalSize { Text("Original: \(size.description)") }
            if let size = run.processedSize { Text("Processed: \(size.description)") }
            if let succeeded = run.subjectLiftingSucceeded { Text("Subject extraction: \(succeeded ? "success" : "fallback")") }
            if let source = run.subjectImageSource { Text("Analysis image: \(source)") }
            if let count = run.subjectCount { Text("Subjects found: \(count)") }
            if let detail = run.subjectExtractionDetail { Text("Subject extraction detail: \(detail)").foregroundStyle(.orange).textSelection(.enabled) }
            if let observation = run.observation {
                Text("Labels (\(observation.labels.count)): \(labelSummary(observation))")
                Text("Material heuristic: \(observation.material.rawValue) (\(observation.materialConfidence, format: .number.precision(.fractionLength(2))))")
            }
            ForEach(ProcessingStage.allCases, id: \.self) { stage in
                if let duration = run.durations[stage] { Text("\(stage.rawValue): \(duration.formatted(.units(allowed: [.milliseconds])))") }
            }
            if let duration = run.totalDuration { Text("Total: \(duration.formatted(.units(allowed: [.milliseconds])))") }
            if let bytes = run.approximateMemoryBytes { Text("Approx. resident memory: \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory))") }
            if let stage = run.failedStage { Text("Failed stage: \(stage.rawValue)").foregroundStyle(.red) }
            if let error = run.error { Text("Full error: \(error)").foregroundStyle(.red).textSelection(.enabled) }
        }
    }

    private func labelSummary(_ observation: ObjectObservation) -> String {
        observation.rankedLabels.map { "\($0.label) (\(String(format: "%.3f", $0.confidence)))" }.joined(separator: ", ")
    }
}

private struct RunComparisonView: View {
    let first: DiagnosticRun
    let second: DiagnosticRun

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("First vs second run").font(.caption.bold())
            comparison("Fingerprint", short(first.fingerprint), short(second.fingerprint))
            comparison("Labels + confidence", labels(first), labels(second))
            comparison("Material + confidence", material(first), material(second))
            comparison("Name", first.draft?.name, second.draft?.name)
            comparison("Species", "Not generated by this PoC", "Not generated by this PoC")
            comparison("Archetype", first.draft?.role, second.draft?.role)
            comparison("Affinity", "Not generated by this PoC", "Not generated by this PoC")
            comparison("Rarity hint", "Not generated by this PoC", "Not generated by this PoC")
            comparison("Stats", stats(first), stats(second))
            comparison("Duration", duration(first), duration(second))
        }
    }

    private func comparison(_ name: String, _ first: String?, _ second: String?) -> some View {
        let lhs = first ?? "—"
        let rhs = second ?? "—"
        return Text("\(name): \(lhs) → \(rhs) \(lhs == rhs ? "=" : "≠")")
    }

    private func short(_ value: String) -> String { value.isEmpty ? "—" : String(value.prefix(12)) }
    private func labels(_ run: DiagnosticRun) -> String? {
        run.observation?.rankedLabels.map { "\($0.label):\(String(format: "%.3f", $0.confidence))" }.joined(separator: ", ")
    }
    private func material(_ run: DiagnosticRun) -> String? {
        run.observation.map { "\($0.material.rawValue):\(String(format: "%.2f", $0.materialConfidence))" }
    }
    private func stats(_ run: DiagnosticRun) -> String? {
        run.stats.map { "D\($0.defense) P\($0.power) A\($0.agility) E\($0.energy)" }
    }
    private func duration(_ run: DiagnosticRun) -> String? {
        run.totalDuration?.formatted(.units(allowed: [.milliseconds]))
    }
}
#endif

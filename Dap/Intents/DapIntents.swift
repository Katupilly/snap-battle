//
//  DapIntents.swift
//  Dap
//

import AppIntents
import Observation

@MainActor
@Observable
final class AppIntentRouter {
    enum Request: Equatable { case create, playLast }
    static let shared = AppIntentRouter()
    var request: Request?
    private init() {}
}

struct CreatePedalIntent: AppIntent {
    static let title: LocalizedStringResource = "Criar Pedal"
    static let description = IntentDescription("Abre a câmera para criar um novo Dap.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { AppIntentRouter.shared.request = .create }
        return .result()
    }
}

struct PlayLastPedalIntent: AppIntent {
    static let title: LocalizedStringResource = "Tocar Pedal"
    static let description = IntentDescription("Toca o último Dap criado.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { AppIntentRouter.shared.request = .playLast }
        return .result()
    }
}

struct DapShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CreatePedalIntent(), phrases: ["Criar pedal no \(.applicationName)", "Nova foto no \(.applicationName)"], shortTitle: "Criar Pedal", systemImageName: "camera.fill")
        AppShortcut(intent: PlayLastPedalIntent(), phrases: ["Tocar pedal no \(.applicationName)", "Tocar meu último pedal no \(.applicationName)"], shortTitle: "Tocar Pedal", systemImageName: "play.fill")
    }
}

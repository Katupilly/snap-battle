#if DEBUG
import SwiftUI

struct BattleDebugLauncher: View {
    @State private var playerProfile: BattleDebugProfile = .balanced
    @State private var opponentProfile: BattleDebugProfile = .balanced
    @State private var showingBattle = false
    @State private var battleID = UUID()

    var body: some View {
        Form {
            Section("Fixtures") {
                Picker("Player", selection: $playerProfile) {
                    ForEach(BattleDebugProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                Picker("Opponent", selection: $opponentProfile) {
                    ForEach(BattleDebugProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
            }

            Section {
                Button {
                    battleID = UUID()
                    showingBattle = true
                } label: {
                    Label("Start debug battle", systemImage: "play.fill")
                }
            } footer: {
                Text("DEBUG only. Uses deterministic local fixtures and bypasses the capture pipeline.")
            }
        }
        .navigationTitle("Battle Debug")
        .navigationDestination(isPresented: $showingBattle) {
            BattleView(player: playerProfile.creature, opponent: opponentProfile.creature)
                .id(battleID)
        }
    }
}
#endif

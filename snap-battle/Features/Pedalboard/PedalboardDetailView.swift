import SwiftUI

struct PedalboardDetailView: View {
    let boardID: Pedalboard.ID
    let model: PedalboardsViewModel
    @State private var draftName = ""
    @State private var isShowingPedalPicker = false
    @FocusState private var isNameFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let board = model.selectedBoard, board.id == boardID {
                editor(for: board)
            } else {
                ProgressView("Carregando pedalboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(model.selectedBoard?.name ?? "Pedalboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .accessibilityLabel("Reordenar pedalboard")
                    .accessibilityHint("Mostra controles nativos para mover e remover pedais")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.reloadLibrary()
                    isShowingPedalPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Adicionar pedal")
                .accessibilityHint("Abre a biblioteca para adicionar pedais a este pedalboard")
            }
        }
        .sheet(isPresented: $isShowingPedalPicker) {
            PedalPickerView(pedals: model.availablePedals) { pedal in
                model.addPedal(pedal)
                isShowingPedalPicker = false
            }
        }
        .alert("Não foi possível tocar", isPresented: Binding(get: { model.playbackErrorMessage != nil }, set: { if !$0 { model.playbackErrorMessage = nil } })) {
            Button("OK", role: .cancel) { model.playbackErrorMessage = nil }
        } message: {
            Text(model.playbackErrorMessage ?? "")
        }
        .alert("Não foi possível salvar", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task(id: boardID) {
            if model.openBoard(id: boardID) {
                draftName = model.selectedBoard?.name ?? ""
            } else {
                dismiss()
            }
        }
        .onChange(of: isNameFocused) { _, isFocused in
            if !isFocused {
                commitRename()
            }
        }
        .onDisappear {
            model.closeBoard()
        }
    }

    private func editor(for board: Pedalboard) -> some View {
        let playbackState = model.playbackCoordinator?.state ?? model.playbackState
        let activeEntryID = activeEntryID(from: playbackState, boardID: board.id)
        let isPlaybackBusy = isPlaybackBusy(playbackState)
        return List {
            Section {
                TextField("Nome do pedalboard", text: $draftName)
                    .focused($isNameFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(commitRename)
                    .accessibilityLabel("Nome do pedalboard")
                    .accessibilityHint("Edite e confirme para renomear")
            }

            Section {
                playbackControls(for: board, playbackState: playbackState, isPlaybackBusy: isPlaybackBusy)
            }

            Section {
                if model.entryDisplays.isEmpty {
                    ContentUnavailableView {
                        Label("Pedalboard vazio", systemImage: "music.note")
                    } description: {
                        Text("Adicione pedais da biblioteca para montar uma sequência reproduzível.")
                    } actions: {
                        Button("Adicionar pedal") {
                            model.reloadLibrary()
                            isShowingPedalPicker = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top: 18, leading: 0, bottom: 18, trailing: 0))
                } else {
                    ForEach(model.entryDisplays) { display in
                        PedalboardEntryRow(
                            display: display,
                            isActive: activeEntryID == display.id,
                            canMoveUp: display.index > 0,
                            canMoveDown: display.index < model.entryDisplays.count - 1,
                            moveUp: { model.moveEntry(id: display.id, to: display.index - 1) },
                            moveDown: { model.moveEntry(id: display.id, to: display.index + 1) },
                            remove: { model.removeEntry(id: display.id) }
                        )
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            guard model.entryDisplays.indices.contains(index) else { continue }
                            model.removeEntry(id: model.entryDisplays[index].id)
                        }
                    }
                    .onMove(perform: model.moveEntries)
                }
            } header: {
                Text("Sequência")
            }
        }
        .accessibilityLabel("Editor de pedalboard")
        .onChange(of: playbackState) { _, state in
            model.updatePlaybackErrorMessage(from: state)
        }
    }

    private func playbackControls(
        for board: Pedalboard,
        playbackState: PedalboardPlaybackState,
        isPlaybackBusy: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                model.play()
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPlaybackBusy)
            .accessibilityLabel("Reproduzir pedalboard")
            .accessibilityHint("Toca a sequência atual do pedalboard")

            Button {
                model.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!isPlaybackBusy)
            .accessibilityLabel("Parar reprodução")
            .accessibilityHint("Interrompe a reprodução do pedalboard")
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(playbackStatusText(for: board, playbackState: playbackState))
    }

    private func playbackStatusText(for board: Pedalboard, playbackState: PedalboardPlaybackState) -> String {
        switch playbackState {
        case .playing(let boardID, _, let index, let total) where boardID == board.id:
            return "Reprodução em andamento, pedal \(index + 1) de \(total)"
        case .preparing(let boardID) where boardID == board.id:
            return "Preparando reprodução"
        case .stopping:
            return "Parando reprodução"
        case .finished(let boardID) where boardID == board.id:
            return "Reprodução finalizada"
        case .failed(let boardID, _) where boardID == board.id || boardID == nil:
            return "Reprodução falhou"
        case .idle, .preparing, .playing, .finished, .failed:
            return "Reprodução parada"
        }
    }

    private func activeEntryID(from state: PedalboardPlaybackState, boardID: Pedalboard.ID) -> PedalboardEntry.ID? {
        if case .playing(let playingBoardID, let entryID, _, _) = state, playingBoardID == boardID {
            return entryID
        }
        return nil
    }

    private func isPlaybackBusy(_ state: PedalboardPlaybackState) -> Bool {
        switch state {
        case .preparing, .playing, .stopping:
            return true
        case .idle, .finished, .failed:
            return false
        }
    }

    private func commitRename() {
        let normalizedDraft = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDraft.isEmpty, normalizedDraft != model.selectedBoard?.name else {
            draftName = model.selectedBoard?.name ?? draftName
            return
        }
        model.renameSelectedBoard(draftName)
        draftName = model.selectedBoard?.name ?? draftName
    }
}

private struct PedalboardEntryRow: View {
    let display: PedalboardEntryDisplay
    let isActive: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if isActive {
                    Label("Tocando agora", systemImage: "waveform")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Tocando agora")
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 6) {
                Button(action: moveUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)
                .accessibilityLabel("Mover pedal para cima")

                Button(action: moveDown) {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)
                .accessibilityLabel("Mover pedal para baixo")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive, action: remove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remover pedal do pedalboard")
            .accessibilityHint("Remove apenas esta ocorrência da sequência")
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch display.status {
        case .available(let pedal):
            Image(uiImage: pedal.cover)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        case .missing:
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 54, height: 54)
                .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private var title: String {
        switch display.status {
        case .available(let pedal):
            pedal.pedal.name
        case .missing:
            "Pedal indisponível"
        }
    }

    private var subtitle: String {
        switch display.status {
        case .available(let pedal):
            pedal.pedal.effect.displayName
        case .missing:
            "Referência preservada na posição \(display.index + 1)"
        }
    }

    private var accessibilityLabel: String {
        let state = isActive ? ", tocando agora" : ""
        return "Posição \(display.index + 1), \(title), \(subtitle)\(state)"
    }
}

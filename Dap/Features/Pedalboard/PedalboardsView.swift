import SwiftUI

struct PedalboardsView: View {
    let model: PedalboardsViewModel
    let openBoard: (Pedalboard.ID) -> Void

    var body: some View {
        content(for: model.state)
            .navigationTitle("Jam")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let id = model.createBoard() {
                            openBoard(id)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(model.isCreatingBoard)
                    .accessibilityLabel("Criar pedalboard")
                    .accessibilityHint("Cria um pedalboard vazio e abre o editor")
                }
            }
            .alert("Não foi possível atualizar", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .task {
                model.reload()
            }
    }

    @ViewBuilder
    private func content(for state: PedalboardsViewState) -> some View {
        switch state {
        case .loading:
            ProgressView("Carregando pedalboards")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView {
                Label("Nenhum pedalboard", systemImage: "music.note.list")
            } description: {
                Text("Um pedalboard organiza vários pedais em uma sequência reproduzível.")
            } actions: {
                Button("Criar pedalboard") {
                    if let id = model.createBoard() {
                        openBoard(id)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isCreatingBoard)
                .accessibilityHint("Cria um pedalboard vazio e abre o editor")
            }
        case .blockingError(let message):
            ContentUnavailableView {
                Label("Pedalboards indisponíveis", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Tentar novamente") { model.reload() }
                    .buttonStyle(.bordered)
            }
        case .content(let boards):
            boardList(boards)
        case .partialError(let boards, let message):
            boardList(boards)
                .safeAreaInset(edge: .top) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
        }
    }

    private func boardList(_ boards: [Pedalboard]) -> some View {
        List(boards) { board in
            NavigationLink(value: AppRoute.pedalboardDetail(board.id)) {
                PedalboardSummaryRow(board: board)
            }
            .accessibilityLabel("\(board.name), \(entryCountText(board.entries.count))")
            .accessibilityHint("Abre o editor do pedalboard")
        }
        .refreshable { model.reload() }
    }

    private func entryCountText(_ count: Int) -> String {
        count == 1 ? "1 pedal" : "\(count) pedais"
    }
}

private struct PedalboardSummaryRow: View {
    let board: Pedalboard

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(board.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(entryCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
    }

    private var entryCountText: String {
        board.entries.count == 1 ? "1 pedal" : "\(board.entries.count) pedais"
    }
}

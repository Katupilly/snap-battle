import SwiftUI

struct TimingBar: View {
    let round: Int
    let agility: Int
    let balance: BattleBalance
    let confirm: (Double) -> Void

    @State private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            let position = timingPosition(at: timeline.date)
            Button {
                confirm(position)
            } label: {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let goodWidth = width * balance.goodTimingHalfWidth(for: agility) * 2
                    let perfectWidth = width * balance.perfectTimingHalfWidth * 2
                    ZStack(alignment: .leading) {
                        Capsule().fill(.secondary.opacity(0.15))
                        Capsule().fill(.green.opacity(0.22)).frame(width: goodWidth).offset(x: (width - goodWidth) / 2)
                        Capsule().fill(.yellow.opacity(0.55)).frame(width: perfectWidth).offset(x: (width - perfectWidth) / 2)
                        Circle()
                            .fill(.tint)
                            .frame(width: 24, height: 24)
                            .overlay { Circle().stroke(.white, lineWidth: 2) }
                            .shadow(radius: 1)
                            .offset(x: max(0, width - 24) * position)
                    }
                }
                .frame(height: 26)
            }
            .buttonStyle(.plain)
        }
        .id(round)
        .onAppear { startedAt = Date() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Timing meter")
        .accessibilityHint("Tap the meter or use Confirm timing to lock your action.")
        .overlay(alignment: .bottom) {
            Button("Confirm timing") {
                confirm(timingPosition(at: Date()))
            }
            .buttonStyle(.bordered)
            .padding(.top, 42)
        }
        .padding(.bottom, 42)
    }

    private func timingPosition(at date: Date) -> Double {
        guard !reduceMotion else { return 0.5 }
        let elapsed = date.timeIntervalSince(startedAt)
        let cycle = elapsed.truncatingRemainder(dividingBy: 2)
        return cycle <= 1 ? cycle : 2 - cycle
    }
}

import SwiftUI

struct CustomBottomNavigation: View {
    private enum Metrics {
        static let height: CGFloat = 68
        static let galleryJamWidth: CGFloat = 216
        static let captureWidth: CGFloat = 88
        static let gap: CGFloat = 22
        static let horizontalMargin: CGFloat = 18
        static let bottomPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 34
    }

    let selectedTab: RootDestination
    let selectTab: (RootDestination) -> Void
    let capture: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Metrics.gap) {
            GalleryJamCapsule(selectedTab: selectedTab, selectTab: selectTab)
                .frame(width: Metrics.galleryJamWidth, height: Metrics.height)

            CaptureCapsule(action: capture)
                .frame(width: Metrics.captureWidth, height: Metrics.height)
        }
        .padding(.horizontal, Metrics.horizontalMargin)
        .padding(.top, 8)
        .padding(.bottom, Metrics.bottomPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
        .accessibilityIdentifier("bottomBar.root")
    }
}

private struct GalleryJamCapsule: View {
    private enum Metrics {
        static let outerRadius: CGFloat = 34
        static let inset: CGFloat = 5
        static let innerRadius: CGFloat = outerRadius - inset
        static let indicatorWidth: CGFloat = 103
        static let indicatorHeight: CGFloat = 58
        static let indicatorTravel: CGFloat = indicatorWidth / 2
        static let itemSpacing: CGFloat = 4
        static let iconSize: CGFloat = 20
        static let iconFrame: CGFloat = 24
        static let pressDirectionalOffset: CGFloat = 7
    }

    let selectedTab: RootDestination
    let selectTab: (RootDestination) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var pressedTab: RootDestination?

    var body: some View {
        ZStack {
            baseFrostedGlass
                .zIndex(0)

            movingSelectionHighlight
                .zIndex(1)

            HStack(spacing: 0) {
                tabButton(.gallery)
                tabButton(.jam)
            }
            .padding(Metrics.inset)
            .zIndex(2)
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.12), radius: 16, y: 8)
    }

    private func tabButton(_ tab: RootDestination) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            if reduceMotion {
                selectTab(tab)
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    selectTab(tab)
                }
            }
        } label: {
            VStack(spacing: Metrics.itemSpacing) {
                Image(systemName: tabSymbol(tab))
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? Color.white : inactiveForeground)
                    .frame(width: Metrics.iconFrame, height: Metrics.iconFrame)

                Text(tab.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .foregroundStyle(isSelected ? Color.white : inactiveForeground)
            }
                .shadow(color: isSelected ? .black.opacity(0.24) : .clear, radius: 2, y: 1)
                .frame(maxWidth: .infinity, minHeight: Metrics.indicatorHeight)
                .contentShape(Capsule())
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(pressGesture(for: tab))
        .accessibilityLabel(tab.title)
        .accessibilityHint("Shows \(tab.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private var baseFrostedGlass: some View {
        GlassEffectContainer(spacing: 8) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.tint(backgroundTint).interactive(), in: .capsule)
        }
        .overlay {
            Capsule()
                .stroke(.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var movingSelectionHighlight: some View {
        Capsule()
            .fill(selectionFill)
            .frame(width: Metrics.indicatorWidth, height: Metrics.indicatorHeight)
            .overlay {
                Capsule()
                    .stroke(selectionStroke, lineWidth: 1)
            }
            .scaleEffect(x: lensScaleX, y: lensScaleY)
            .offset(x: lensOffset)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: selectedTab)
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.94), value: pressedTab)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var lensOffset: CGFloat {
        baseOffset(for: selectedTab) + pressOffset
    }

    private var lensScaleX: CGFloat {
        guard !reduceMotion, pressedTab != nil else { return 1 }
        return isPressingSelectedTab ? 1.02 : 1.06
    }

    private var lensScaleY: CGFloat {
        guard !reduceMotion, pressedTab != nil else { return 1 }
        return 0.96
    }

    private var pressOffset: CGFloat {
        guard !reduceMotion, let pressedTab, pressedTab != selectedTab else { return 0 }
        return baseOffset(for: pressedTab) > baseOffset(for: selectedTab)
            ? Metrics.pressDirectionalOffset
            : -Metrics.pressDirectionalOffset
    }

    private var isPressingSelectedTab: Bool {
        pressedTab == selectedTab
    }

    private func baseOffset(for tab: RootDestination) -> CGFloat {
        tab == .gallery ? -Metrics.indicatorTravel : Metrics.indicatorTravel
    }

    private func pressGesture(for tab: RootDestination) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressedTab) { _, state, _ in
                state = tab
            }
    }

    private var backgroundTint: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.04)
    }

    private var selectionFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.46, blue: 0.96).opacity(colorScheme == .dark ? 0.82 : 0.72),
                Color(red: 0.12, green: 0.72, blue: 1.00).opacity(colorScheme == .dark ? 0.62 : 0.54)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var selectionStroke: Color {
        Color.white.opacity(colorScheme == .dark ? 0.34 : 0.44)
    }

    private var inactiveForeground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.70)
            : Color.primary.opacity(0.68)
    }

    private func tabSymbol(_ tab: RootDestination) -> String {
        switch tab {
        case .gallery:
            return "photo.on.rectangle.angled.fill"
        case .jam:
            return "music.note.square.stack.fill"
        }
    }
}

private struct CaptureCapsule: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
        .background {
            CaptureGradientBackground()
                .clipShape(Capsule())
        }
        .glassEffect(.regular.tint(.cyan.opacity(0.12)).interactive(), in: .capsule)
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 14, y: 7)
        .contentShape(.capsule)
        .accessibilityLabel("Capture")
        .accessibilityHint("Opens the camera")
        .accessibilityIdentifier("bottomBar.action.capture")
    }
}

private struct CaptureGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.06, blue: 0.28),
                    Color(red: 0.02, green: 0.24, blue: 0.74),
                    Color(red: 0.08, green: 0.66, blue: 0.96),
                    .white.opacity(0.68),
                    Color(red: 0.06, green: 0.48, blue: 0.94),
                    Color(red: 0.02, green: 0.06, blue: 0.28)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [.clear, .white.opacity(0.40), .cyan.opacity(0.14), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 6)

            RadialGradient(
                colors: [.white.opacity(0.52), .cyan.opacity(0.14), .clear],
                center: .center,
                startRadius: 2,
                endRadius: 20
            )
        }
    }
}

import SwiftUI

struct CustomBottomNavigation: View {
    private enum Metrics {
        static let height: CGFloat = 58
        static let galleryJamWidth: CGFloat = 212
        static let captureWidth: CGFloat = 88
        static let gap: CGFloat = 22
        static let horizontalMargin: CGFloat = 18
        static let bottomPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 29
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
        static let outerRadius: CGFloat = 29
        static let inset: CGFloat = 4
        static let innerRadius: CGFloat = outerRadius - inset
        static let indicatorWidth: CGFloat = 102
        static let indicatorHeight: CGFloat = 50
        static let indicatorTravel: CGFloat = indicatorWidth / 2
    }

    let selectedTab: RootDestination
    let selectTab: (RootDestination) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            baseFrostedGlass
                .zIndex(0)

            movingSelectionHighlight
                .zIndex(1)

            HStack(spacing: 4) {
                tabButton(.gallery)
                Divider()
                    .frame(height: 24)
                    .overlay(.primary.opacity(colorScheme == .dark ? 0.14 : 0.10))
                    .accessibilityHidden(true)
                tabButton(.jam)
            }
            .padding(6)
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
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    selectTab(tab)
                }
            }
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
                .shadow(color: isSelected ? .black.opacity(0.24) : .clear, radius: 2, y: 1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
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
        .overlay(alignment: .top) {
            Capsule()
                .stroke(.white.opacity(colorScheme == .dark ? 0.10 : 0.22), lineWidth: 1)
                .padding(.horizontal, 10)
                .padding(.top, 1)
                .frame(height: 18)
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var movingSelectionHighlight: some View {
        RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
            .fill(selectionFill)
            .frame(width: Metrics.indicatorWidth, height: Metrics.indicatorHeight)
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
                    .stroke(selectionStroke, lineWidth: 1)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
                    .fill(.white.opacity(colorScheme == .dark ? 0.20 : 0.28))
                    .frame(height: 14)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.10), radius: 5, y: 2)
            .shadow(color: Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12), radius: 4, y: 1)
            .offset(x: selectedTab == .gallery ? -Metrics.indicatorTravel : Metrics.indicatorTravel)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: selectedTab)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

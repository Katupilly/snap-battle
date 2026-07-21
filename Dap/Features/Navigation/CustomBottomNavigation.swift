import SwiftUI

struct CustomBottomNavigation: View {
    private enum Metrics {
        static let height: CGFloat = 66
        static let galleryJamWidth: CGFloat = 212
        static let captureWidth: CGFloat = 88
        static let gap: CGFloat = 22
        static let horizontalMargin: CGFloat = 18
        static let bottomPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 33
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
        static let outerRadius: CGFloat = 33
        static let inset: CGFloat = 4
        static let innerRadius: CGFloat = outerRadius - inset
        static let indicatorWidth: CGFloat = 102
        static let indicatorHeight: CGFloat = 58
        static let indicatorTravel: CGFloat = indicatorWidth / 2
        static let itemSpacing: CGFloat = 3
        static let iconSize: CGFloat = 19
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

            HStack(spacing: 0) {
                tabButton(.gallery)
                tabButton(.jam)
            }
            .padding(Metrics.inset)
            .zIndex(2)
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.outerRadius, style: .continuous))
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
                    .font(.system(size: Metrics.iconSize, weight: isSelected ? .semibold : .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(tab.title)
                    .font(.caption2.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(colorScheme == .dark ? 0.76 : 0.68))
                .shadow(color: isSelected ? .black.opacity(0.24) : .clear, radius: 2, y: 1)
                .frame(maxWidth: .infinity, minHeight: Metrics.indicatorHeight)
                .contentShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
        .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(tab.title)
        .accessibilityHint("Shows \(tab.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private var baseFrostedGlass: some View {
        GlassEffectContainer(spacing: 8) {
            RoundedRectangle(cornerRadius: Metrics.outerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(backgroundTint).interactive(), in: .capsule)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.outerRadius, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: Metrics.outerRadius, style: .continuous)
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
                    .fill(specularHighlight)
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

    private var specularHighlight: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.18 : 0.24),
                .white.opacity(colorScheme == .dark ? 0.06 : 0.10),
                .clear
            ],
            startPoint: .top,
            endPoint: .center
        )
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

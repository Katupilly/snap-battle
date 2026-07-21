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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: selectedTab)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
        .accessibilityIdentifier("bottomBar.root")
    }
}

private struct GalleryJamCapsule: View {
    let selectedTab: RootDestination
    let selectTab: (RootDestination) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.gallery)
            Divider()
                .frame(height: 26)
                .overlay(.primary.opacity(0.12))
                .accessibilityHidden(true)
            tabButton(.jam)
        }
        .padding(6)
        .background(glassBackground)
        .glassEffect(.regular.interactive(), in: .capsule)
        .overlay {
            Capsule()
                .stroke(.primary.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 14, y: 7)
    }

    private func tabButton(_ tab: RootDestination) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectTab(tab)
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.82))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Color.accentColor.opacity(0.16) : .clear, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.accentColor.opacity(0.40) : .clear, lineWidth: 1)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityHint("Shows \(tab.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private var glassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.02))
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
        .glassEffect(.regular.interactive(), in: .capsule)
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

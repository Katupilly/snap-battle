import SwiftUI

struct CanvasGridBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let metrics = Metrics(displayScale: displayScale)
        let strokeColor = gridColor(opacity: metrics.lineOpacity)
        let pointColor = gridColor(opacity: metrics.pointOpacity)

        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(uiColor: .systemBackground))
            )

            var linePath = Path()
            for x in stride(from: 0.0, through: size.width + metrics.spacing, by: metrics.spacing) {
                let alignedX = metrics.alignedPosition(for: x)
                linePath.move(to: CGPoint(x: alignedX, y: 0))
                linePath.addLine(to: CGPoint(x: alignedX, y: size.height))
            }

            for y in stride(from: 0.0, through: size.height + metrics.spacing, by: metrics.spacing) {
                let alignedY = metrics.alignedPosition(for: y)
                linePath.move(to: CGPoint(x: 0, y: alignedY))
                linePath.addLine(to: CGPoint(x: size.width, y: alignedY))
            }

            context.stroke(
                linePath,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: metrics.lineWidth)
            )

            var pointPath = Path()

            for x in stride(from: 0.0, through: size.width + metrics.spacing, by: metrics.spacing) {
                let alignedX = metrics.alignedPosition(for: x) - (metrics.pointDiameter / 2)
                for y in stride(from: 0.0, through: size.height + metrics.spacing, by: metrics.spacing) {
                    let alignedY = metrics.alignedPosition(for: y) - (metrics.pointDiameter / 2)
                    pointPath.addEllipse(in: CGRect(x: alignedX, y: alignedY, width: metrics.pointDiameter, height: metrics.pointDiameter))
                }
            }

            context.fill(pointPath, with: .color(pointColor))
        }
    }

    private func gridColor(opacity: Double) -> Color {
        let baseColor: Color = colorScheme == .dark ? .white : .black
        return baseColor.opacity(opacity)
    }
}

private extension CanvasGridBackground {
    struct Metrics {
        let spacing: CGFloat = 44
        let lineOpacity: Double = 0.055
        let pointOpacity: Double = 0.16
        let pointDiameter: CGFloat = 2
        let lineWidth: CGFloat
        let displayScale: CGFloat

        init(displayScale: CGFloat) {
            self.displayScale = max(displayScale, 1)
            lineWidth = 1 / self.displayScale
        }

        func alignedPosition(for value: CGFloat) -> CGFloat {
            (floor(value * displayScale) + 0.5) / displayScale
        }
    }
}

#Preview("Canvas Grid Light") {
    CanvasGridBackground()
}

#Preview("Canvas Grid Dark") {
    CanvasGridBackground()
        .preferredColorScheme(.dark)
}

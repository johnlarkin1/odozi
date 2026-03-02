import SwiftUI

struct RadialChartView: View {
    let metric: MetricDefinition
    let data: [(Date, Double)]

    private let ringCount = 4

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 30

            Canvas { context, _ in
                // Reference rings
                for i in 1...ringCount {
                    let r = radius * Double(i) / Double(ringCount)
                    let ringRect = CGRect(
                        x: center.x - r,
                        y: center.y - r,
                        width: r * 2,
                        height: r * 2
                    )
                    context.stroke(
                        Path(ellipseIn: ringRect),
                        with: .color(.starWhite.opacity(0.1)),
                        lineWidth: 0.5
                    )
                }

                // Data points
                let recentData = Array(data.suffix(7))
                guard recentData.count >= 2 else { return }

                let maxVal = recentData.map(\.1).max() ?? 1
                let normalizedMax = max(maxVal, 1)

                var path = Path()
                var fillPath = Path()

                for (i, point) in recentData.enumerated() {
                    let angle = (Double(i) / Double(recentData.count)) * 2 * .pi - .pi / 2
                    let normalizedValue = point.1 / normalizedMax
                    let pointRadius = radius * normalizedValue
                    let x = center.x + cos(angle) * pointRadius
                    let y = center.y + sin(angle) * pointRadius

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                        fillPath.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                        fillPath.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
                fillPath.closeSubpath()

                // Fill
                context.fill(
                    fillPath,
                    with: .color(metric.color.opacity(0.15))
                )

                // Stroke
                context.stroke(
                    path,
                    with: .color(metric.color),
                    lineWidth: 2
                )

                // Day labels
                for (i, point) in recentData.enumerated() {
                    let angle = (Double(i) / Double(recentData.count)) * 2 * .pi - .pi / 2
                    let labelRadius = radius + 18
                    let x = center.x + cos(angle) * labelRadius
                    let y = center.y + sin(angle) * labelRadius

                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE"
                    let label = formatter.string(from: point.0)

                    context.draw(
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary),
                        at: CGPoint(x: x, y: y)
                    )
                }
            }
            .drawingGroup()
        }
        .frame(height: 280)
    }
}

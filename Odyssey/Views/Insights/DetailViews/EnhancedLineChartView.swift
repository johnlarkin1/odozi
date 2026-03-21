import Charts
import SwiftUI

struct EnhancedLineChartView: View {
    let metric: MetricDefinition
    let data: [(Date, Double)]
    let average: Double

    var body: some View {
        VStack(spacing: 16) {
            Chart {
                ForEach(data, id: \.0) { point in
                    LineMark(
                        x: .value("Date", point.0),
                        y: .value(metric.displayName, point.1)
                    )
                    .foregroundStyle(metric.color)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.0),
                        y: .value(metric.displayName, point.1)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [metric.color.opacity(0.3), metric.color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("Average", average))
                    .foregroundStyle(metric.color.opacity(0.4))
                    .lineStyle(StrokeStyle(dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(metric.formatValue(average))")
                            .font(.caption2)
                            .foregroundStyle(metric.color.opacity(0.6))
                    }
            }
            .frame(height: 280)
            .chartYAxisLabel(metric.unit)
        }
    }
}

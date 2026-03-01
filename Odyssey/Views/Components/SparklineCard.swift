import SwiftUI

struct SparklineCard: View {
    let metric: MetricDefinition
    let value: String
    let data: [(Date, Double)]
    let trend: TrendCalculator.Trend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: metric.icon)
                    .font(.caption)
                    .foregroundStyle(metric.color)
                Text(metric.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                TrendArrow(trend: trend)
            }

            // Sparkline
            if data.count >= 2 {
                SparklineChartView(data: data, color: metric.color)
            } else {
                Rectangle()
                    .fill(Color.cardSurface)
                    .frame(height: 40)
                    .overlay(
                        Text("Not enough data")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
            }

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                Text(metric.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cosmicCard(accent: metric.color)
    }
}

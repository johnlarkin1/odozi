import Charts
import SwiftUI

struct ScatterCorrelationView: View {
    let primaryMetric: MetricDefinition
    let viewModel: InsightsViewModel
    @State private var comparedMetric: MetricDefinition = .sleepRating

    var body: some View {
        VStack(spacing: 16) {
            // Metric picker for Y axis
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MetricDefinition.allCases.filter { $0 != primaryMetric }) { metric in
                        Button {
                            withAnimation { comparedMetric = metric }
                        } label: {
                            Text(metric.displayName)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(comparedMetric == metric ? metric.color.opacity(0.3) : Color.cardSurface))
                                .foregroundStyle(comparedMetric == metric ? metric.color : .secondary)
                        }
                    }
                }
            }

            // Scatter chart
            let pairs = scatterPairs
            Chart {
                ForEach(pairs, id: \.0) { pair in
                    PointMark(
                        x: .value(primaryMetric.displayName, pair.1),
                        y: .value(comparedMetric.displayName, pair.2)
                    )
                    .foregroundStyle(primaryMetric.color.opacity(0.7))
                    .symbolSize(40)
                }

                // Regression line
                if let regression = regressionLine(pairs: pairs) {
                    LineMark(
                        x: .value("", regression.x1),
                        y: .value("", regression.y1)
                    )
                    .foregroundStyle(Color.starWhite.opacity(0.4))
                    .lineStyle(StrokeStyle(dash: [4, 4]))

                    LineMark(
                        x: .value("", regression.x2),
                        y: .value("", regression.y2)
                    )
                    .foregroundStyle(Color.starWhite.opacity(0.4))
                    .lineStyle(StrokeStyle(dash: [4, 4]))
                }
            }
            .frame(height: 280)
            .chartXAxisLabel(primaryMetric.displayName)
            .chartYAxisLabel(comparedMetric.displayName)

            // Correlation coefficient
            if let corr = CorrelationService.correlate(primaryMetric, comparedMetric, entries: viewModel.filteredEntries) {
                Text(corr.insightText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var scatterPairs: [(Date, Double, Double)] {
        viewModel.filteredEntries.compactMap { entry in
            guard let x = primaryMetric.value(from: entry),
                  let y = comparedMetric.value(from: entry) else { return nil }
            return (entry.date, x, y)
        }
    }

    private func regressionLine(pairs: [(Date, Double, Double)]) -> (x1: Double, y1: Double, x2: Double, y2: Double)? {
        guard pairs.count >= 3 else { return nil }

        let xs = pairs.map(\.1)
        let ys = pairs.map(\.2)
        let n = Double(pairs.count)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map(*).reduce(0, +)
        let sumX2 = xs.map { $0 * $0 }.reduce(0, +)

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n

        guard let minX = xs.min(), let maxX = xs.max() else { return nil }

        return (minX, slope * minX + intercept, maxX, slope * maxX + intercept)
    }
}

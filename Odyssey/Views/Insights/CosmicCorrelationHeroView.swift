import Charts
import SwiftUI

struct CosmicCorrelationHeroView: View {
    let viewModel: InsightsViewModel

    var body: some View {
        if let correlation = viewModel.strongestCorrelation {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .foregroundStyle(Color.cosmicPurple)
                    Text("Cosmic Correlation")
                        .font(.subheadline.weight(.medium))
                }

                // Mini scatter preview
                let pairs = scatterPairs(a: correlation.metricA, b: correlation.metricB)
                if pairs.count >= 3 {
                    Chart {
                        ForEach(pairs, id: \.0) { pair in
                            PointMark(
                                x: .value(correlation.metricA.displayName, pair.1),
                                y: .value(correlation.metricB.displayName, pair.2)
                            )
                            .foregroundStyle(correlation.metricA.color.opacity(0.7))
                            .symbolSize(30)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 80)
                }

                Text(correlation.insightText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    ScatterCorrelationView(primaryMetric: correlation.metricA, viewModel: viewModel)
                        .navigationTitle("Correlation Explorer")
                        .cosmicBackground()
                } label: {
                    HStack {
                        Text("Explore")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.cosmicPurple)
                }
            }
            .cosmicCard(accent: .cosmicPurple)
        }
    }

    private func scatterPairs(a: MetricDefinition, b: MetricDefinition) -> [(Date, Double, Double)] {
        viewModel.filteredEntries.compactMap { entry in
            guard let va = a.value(from: entry),
                  let vb = b.value(from: entry) else { return nil }
            return (entry.date, va, vb)
        }
    }
}

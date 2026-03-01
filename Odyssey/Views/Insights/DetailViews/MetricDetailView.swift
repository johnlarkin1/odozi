import SwiftUI

struct MetricDetailView: View {
    let metric: MetricDefinition
    let viewModel: InsightsViewModel
    @State private var chartMode: ChartMode = .line

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Chart mode picker
                ChartModePicker(selection: $chartMode, availableModes: metric.availableChartModes)
                    .padding(.horizontal, 16)

                // Chart content
                Group {
                    switch chartMode {
                    case .line:
                        EnhancedLineChartView(
                            metric: metric,
                            data: viewModel.sparklineData(for: metric),
                            average: viewModel.average(for: metric)
                        )
                    case .radial:
                        RadialChartView(
                            metric: metric,
                            data: viewModel.sparklineData(for: metric)
                        )
                    case .scatter:
                        ScatterCorrelationView(
                            primaryMetric: metric,
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.horizontal, 16)
                .transition(.opacity)

                // Stats summary
                HStack(spacing: 12) {
                    statBox("Average", value: metric.formatValue(viewModel.average(for: metric)), color: metric.color)

                    let data = viewModel.sparklineData(for: metric)
                    if let maxVal = data.map(\.1).max() {
                        statBox("Best", value: metric.formatValue(maxVal), color: .successGreen)
                    }
                    if let minVal = data.map(\.1).min() {
                        statBox("Low", value: metric.formatValue(minVal), color: .coralRed)
                    }
                }
                .padding(.horizontal, 16)

                // Trend
                let trend = viewModel.trend(for: metric)
                HStack {
                    Text("Trend")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    TrendArrow(trend: trend)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
        .navigationTitle(metric.displayName)
        .cosmicBackground()
    }

    private func statBox(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .fontDesign(.rounded)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
    }
}

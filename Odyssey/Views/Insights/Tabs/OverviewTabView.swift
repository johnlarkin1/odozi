import SwiftUI

struct OverviewTabView: View {
    let viewModel: InsightsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Curated sparkline cards
                LazyVGrid(columns: columns, spacing: 12) {
                    sparklineNavigationCard(for: .mood)
                    sparklineNavigationCard(for: .sleepRating)
                    sparklineNavigationCard(for: .steps)
                    sparklineNavigationCard(for: .sleepHours)
                    sparklineNavigationCard(for: .screenTime)
                    sparklineNavigationCard(for: .walkingDistance)
                }
                .padding(.horizontal, 16)

                // Cosmic Correlation hero
                CosmicCorrelationHeroView(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Journey Explorer banner
                NavigationLink(destination: JourneyExplorerView()) {
                    HStack(spacing: 14) {
                        Image(systemName: "globe.americas.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.accentTeal, Color.accentAmber],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Journey Explorer")
                                .font(.title3.bold())
                            Text("Explore your world")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentTeal.opacity(0.2), Color.accentAmber.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func sparklineNavigationCard(for metric: MetricDefinition) -> some View {
        NavigationLink(destination: SpecialDetailRouter.destination(for: metric, viewModel: viewModel)) {
            SparklineCard(
                metric: metric,
                value: metric.formatValue(viewModel.average(for: metric)),
                data: viewModel.sparklineData(for: metric),
                trend: viewModel.trend(for: metric)
            )
        }
        .buttonStyle(.plain)
    }
}

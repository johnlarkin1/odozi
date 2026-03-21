import SwiftUI

struct OverviewTabView: View {
    let viewModel: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mind section
                sectionHeader("Mind")
                MindCardsGrid(viewModel: viewModel)
                    .adaptiveHorizontalPadding()

                // Body section
                sectionHeader("Body")
                AdaptiveGrid(minColumnWidth: 160, spacing: 12) {
                    sparklineNavigationCard(for: .steps)
                    sparklineNavigationCard(for: .walkingDistance)
                    sparklineNavigationCard(for: .sleepHours)
                }
                .adaptiveHorizontalPadding()

                // World section
                sectionHeader("World")
                AdaptiveGrid(minColumnWidth: 160, spacing: 12) {
                    sparklineNavigationCard(for: .screenTime)
                    sparklineNavigationCard(for: .pickups)
                }
                .adaptiveHorizontalPadding()

                citiesCountriesCard
                    .adaptiveHorizontalPadding()

                // Cosmic Correlation hero
                CosmicCorrelationHeroView(viewModel: viewModel)
                    .adaptiveHorizontalPadding()

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
                .adaptiveHorizontalPadding()

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveHorizontalPadding()
    }

    // MARK: - Sparkline Navigation Card

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

    // MARK: - Insight Cards

    private var citiesCountriesCard: some View {
        NavigationLink(destination: MapVisualizationView(entries: viewModel.filteredEntries)) {
            let cities = Set(viewModel.filteredEntries.compactMap(\.city))
            InsightCard(title: "My Map", icon: "map.fill", color: .accentTeal) {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cities.count)")
                            .font(.title2.bold())
                            .fontDesign(.rounded)
                        Text("cities")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let countries = Set(viewModel.filteredEntries.compactMap(\.country))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(countries.count)")
                            .font(.title2.bold())
                            .fontDesign(.rounded)
                        Text("countries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

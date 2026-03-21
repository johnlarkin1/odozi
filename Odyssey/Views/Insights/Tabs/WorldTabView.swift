import SwiftUI

struct WorldTabView: View {
    let viewModel: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Map card (full width)
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
                .adaptiveHorizontalPadding()

                // Screen Time & Pickups
                AdaptiveGrid(minColumnWidth: 160, spacing: 12) {
                    NavigationLink(destination: MetricDetailView(metric: .screenTime, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .screenTime,
                            value: MetricDefinition.screenTime.formatValue(viewModel.averageScreenTimeHours),
                            data: viewModel.sparklineData(for: .screenTime),
                            trend: viewModel.trend(for: .screenTime)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: MetricDetailView(metric: .pickups, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .pickups,
                            value: MetricDefinition.pickups.formatValue(viewModel.averagePickups),
                            data: viewModel.sparklineData(for: .pickups),
                            trend: viewModel.trend(for: .pickups)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .adaptiveHorizontalPadding()

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }
}

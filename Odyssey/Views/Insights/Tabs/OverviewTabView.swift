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
                // Mind section
                sectionHeader("Mind")
                LazyVGrid(columns: columns, spacing: 12) {
                    sparklineNavigationCard(for: .mood)
                    sparklineNavigationCard(for: .sleepRating)
                    sparklineNavigationCard(for: .drinks)
                    feelingWordsCard
                    colorPaletteCard
                    streaksCard
                }
                .padding(.horizontal, 16)

                // Body section
                sectionHeader("Body")
                LazyVGrid(columns: columns, spacing: 12) {
                    sparklineNavigationCard(for: .steps)
                    sparklineNavigationCard(for: .walkingDistance)
                    sparklineNavigationCard(for: .sleepHours)
                }
                .padding(.horizontal, 16)

                // World section
                sectionHeader("World")
                LazyVGrid(columns: columns, spacing: 12) {
                    sparklineNavigationCard(for: .screenTime)
                    sparklineNavigationCard(for: .pickups)
                }
                .padding(.horizontal, 16)

                citiesCountriesCard
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

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
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

    private var feelingWordsCard: some View {
        NavigationLink(destination: WordCloudView(words: viewModel.topFeelingWords)) {
            InsightCard(title: "Feeling Words", icon: "textformat", color: .coralRed) {
                if let top = viewModel.topFeelingWords.first {
                    Text(top.word)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("No data")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var colorPaletteCard: some View {
        NavigationLink(destination: ColorPaletteView(colors: viewModel.feelingColors)) {
            InsightCard(title: "Color Palette", icon: "paintpalette.fill", color: .purple) {
                HStack(spacing: -4) {
                    ForEach(viewModel.feelingColors.prefix(5), id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var streaksCard: some View {
        NavigationLink(destination: StreakView(currentStreak: viewModel.currentStreak, longestStreak: viewModel.longestStreak, entries: viewModel.filteredEntries)) {
            InsightCard(title: "Streaks", icon: "flame.fill", color: .accentAmber) {
                HStack(spacing: 4) {
                    Text("\(viewModel.currentStreak)")
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                    Text("days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

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

import SwiftUI

/// Shared grid of Mind-section cards used by both OverviewTabView and MindTabView.
struct MindCardsGrid: View {
    let viewModel: InsightsViewModel

    var body: some View {
        AdaptiveGrid(minColumnWidth: 160, spacing: 12) {
            sparklineNavigationCard(for: .mood)
            sparklineNavigationCard(for: .sleepRating)
            sparklineNavigationCard(for: .drinks)
            feelingWordsCard
            colorPaletteCard
            streaksCard
            achievementsCard
        }
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

    private var achievementsCard: some View {
        NavigationLink(destination: AchievementGalleryView()) {
            InsightCard(title: "Achievements", icon: "trophy.fill", color: .cosmicPurple) {
                HStack(spacing: 4) {
                    Text("\(viewModel.achievementUnlockedCount)")
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                    Text("/ \(viewModel.achievementTotalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("achievementsCard")
    }

    private var streaksCard: some View {
        NavigationLink(destination: StreakView(
            currentStreak: viewModel.currentStreak,
            longestStreak: viewModel.longestStreak,
            entries: viewModel.filteredEntries
        )) {
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
        .accessibilityIdentifier("streaksCard")
    }
}

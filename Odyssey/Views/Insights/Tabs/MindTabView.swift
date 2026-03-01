import SwiftUI

struct MindTabView: View {
    let viewModel: InsightsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(columns: columns, spacing: 12) {
                    // Mood sparkline
                    NavigationLink(destination: MetricDetailView(metric: .mood, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .mood,
                            value: String(format: "%.1f", viewModel.averageMood),
                            data: viewModel.sparklineData(for: .mood),
                            trend: viewModel.trend(for: .mood)
                        )
                    }
                    .buttonStyle(.plain)

                    // Sleep Rating sparkline
                    NavigationLink(destination: MetricDetailView(metric: .sleepRating, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .sleepRating,
                            value: String(format: "%.1f", viewModel.averageSleep),
                            data: viewModel.sparklineData(for: .sleepRating),
                            trend: viewModel.trend(for: .sleepRating)
                        )
                    }
                    .buttonStyle(.plain)

                    // Drinks sparkline
                    NavigationLink(destination: MetricDetailView(metric: .drinks, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .drinks,
                            value: "\(viewModel.totalDrinks)",
                            data: viewModel.sparklineData(for: .drinks),
                            trend: viewModel.trend(for: .drinks)
                        )
                    }
                    .buttonStyle(.plain)

                    // Feeling Words link
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

                    // Color Palette link
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

                    // Streaks link
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
                .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }
}

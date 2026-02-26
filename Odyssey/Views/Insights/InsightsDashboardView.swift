import SwiftUI
import SwiftData

struct InsightsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: InsightsViewModel?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    ScrollView {
                        VStack(spacing: 16) {
                            DateRangePicker(selection: Binding(
                                get: { vm.dateRange },
                                set: { vm.dateRange = $0 }
                            ))

                            LazyVGrid(columns: columns, spacing: 12) {
                                NavigationLink(destination: MoodTrendView(entries: vm.filteredEntries)) {
                                    InsightCard(title: "Mood Trends", icon: "chart.line.uptrend.xyaxis", color: .accentAmber) {
                                        Text(String(format: "%.1f avg", vm.averageMood))
                                            .font(.title2.bold())
                                            .fontDesign(.rounded)
                                            .foregroundStyle(Color.moodGradient(for: Int(vm.averageMood)))
                                    }
                                }
                                .buttonStyle(.plain)

                                NavigationLink(destination: MoodTrendView(entries: vm.filteredEntries)) {
                                    InsightCard(title: "Sleep Quality", icon: "moon.fill", color: .accentTeal) {
                                        Text(String(format: "%.1f avg", vm.averageSleep))
                                            .font(.title2.bold())
                                            .fontDesign(.rounded)
                                            .foregroundStyle(Color.accentTeal)
                                    }
                                }
                                .buttonStyle(.plain)

                                NavigationLink(destination: MapVisualizationView(entries: vm.filteredEntries)) {
                                    InsightCard(title: "My Map", icon: "map.fill", color: .accentTeal) {
                                        let cities = Set(vm.filteredEntries.compactMap(\.city))
                                        Text("\(cities.count) cities")
                                            .font(.title3.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)

                                NavigationLink(destination: StreakView(currentStreak: vm.currentStreak, longestStreak: vm.longestStreak, entries: vm.filteredEntries)) {
                                    InsightCard(title: "Streaks", icon: "flame.fill", color: .accentAmber) {
                                        HStack(spacing: 4) {
                                            Text("\(vm.currentStreak)")
                                                .font(.title2.bold())
                                                .fontDesign(.rounded)
                                            Text("days")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                NavigationLink(destination: WordCloudView(words: vm.topFeelingWords)) {
                                    InsightCard(title: "Feeling Words", icon: "textformat", color: .coralRed) {
                                        if let top = vm.topFeelingWords.first {
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

                                NavigationLink(destination: ColorPaletteView(colors: vm.feelingColors)) {
                                    InsightCard(title: "Color Palette", icon: "paintpalette.fill", color: .purple) {
                                        HStack(spacing: -4) {
                                            ForEach(vm.feelingColors.prefix(5), id: \.self) { hex in
                                                Circle()
                                                    .fill(Color(hex: hex))
                                                    .frame(width: 20, height: 20)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)

                            // Year in Review banner
                            NavigationLink(destination: YearInReviewView()) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Year in Review")
                                            .font(.title3.bold())
                                        Text("Your Odyssey, wrapped")
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
                                                colors: [Color.accentAmber.opacity(0.3), Color.accentTeal.opacity(0.3)],
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
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Insights")
            .background(Color.black)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InsightsViewModel(modelContext: modelContext)
            }
            viewModel?.loadEntries()
        }
    }
}

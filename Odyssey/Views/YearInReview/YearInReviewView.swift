import SwiftUI
import SwiftData

struct YearInReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: YearInReviewViewModel?
    @State private var currentPage = 0

    var body: some View {
        Group {
            if let vm = viewModel, let data = vm.data {
                ZStack(alignment: .top) {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Progress dots
                        HStack(spacing: 4) {
                            ForEach(0..<vm.totalCards, id: \.self) { i in
                                Capsule()
                                    .fill(i <= currentPage ? Color.accentAmber : Color.white.opacity(0.2))
                                    .frame(height: 3)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        TabView(selection: $currentPage) {
                            ReviewTitleCard(year: data.year).tag(0)
                            ReviewEntryCountCard(count: data.totalEntries, percentage: data.completionPercentage).tag(1)
                            ReviewMoodCard(averageMood: data.averageMood, moodByMonth: data.moodByMonth).tag(2)
                            ReviewBestDayCard(entry: data.bestDay).tag(3)
                            ReviewWordsCard(words: data.feelingWordCloud).tag(4)
                            ReviewColorsCard(colors: data.allColors).tag(5)
                            ReviewMapCard(cities: data.topCities).tag(6)
                            ReviewSleepCard(averageSleep: data.averageSleep).tag(7)
                            ReviewGratitudeCard(gratitudes: data.topGratitudes).tag(8)
                            ReviewClosingCard(year: data.year, onDismiss: { dismiss() }).tag(9)
                        }
                        #if os(iOS)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        #endif
                    }
                }
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if viewModel == nil {
                viewModel = YearInReviewViewModel(modelContext: modelContext)
            }
            viewModel?.loadData()
        }
    }
}

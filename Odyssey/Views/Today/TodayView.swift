import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingGuidedFlow = false
    @State private var viewModel: DailyEntryViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingText)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text(Date().shortFormatted)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    // Entry status card
                    TodayEntryStatusCard(
                        hasEntry: viewModel?.hasSubmittedData ?? false,
                        entry: viewModel?.fetchTodayEntry(),
                        onBeginEntry: { showingGuidedFlow = true }
                    )
                    .padding(.horizontal, 16)

                    // Quick stats
                    if let vm = viewModel {
                        HStack(spacing: 12) {
                            quickStatCard(
                                icon: "flame.fill",
                                value: "\(vm.currentStreak)",
                                label: "Day Streak",
                                color: .accentAmber
                            )

                            if let yesterday = vm.fetchEntry(for: Date().daysAgo(1)) {
                                quickStatCard(
                                    icon: "face.smiling",
                                    value: "\(yesterday.feeling)/10",
                                    label: "Yesterday",
                                    color: .moodGradient(for: yesterday.feeling)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(Color.black)
            .fullScreenCover(isPresented: $showingGuidedFlow) {
                GuidedPromptFlowView()
            }
            .onChange(of: showingGuidedFlow) { _, newValue in
                if !newValue {
                    viewModel?.checkForTodayEntry()
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DailyEntryViewModel(modelContext: modelContext)
            } else {
                viewModel?.checkForTodayEntry()
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private func quickStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title2.bold())
                    .fontDesign(.rounded)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
        )
    }
}

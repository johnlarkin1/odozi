import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingGuidedFlow = false
    @State private var viewModel: DailyEntryViewModel?
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // [A] Header
                    headerSection

                    // [B] Hero — Mood Orb
                    MoodOrbView(
                        entry: viewModel?.fetchTodayEntry(),
                        hasEntry: viewModel?.hasSubmittedData ?? false,
                        onBeginEntry: { showingGuidedFlow = true },
                        animateIn: animateIn
                    )

                    // [C] Week Pulse
                    if let vm = viewModel {
                        WeekPulseView(
                            weekEntries: vm.fetchWeekEntries(),
                            animateIn: animateIn
                        )
                        .padding(.horizontal, 16)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: animateIn)
                    }

                    // [D] Vitals Grid
                    if let vm = viewModel {
                        VitalsGridView(
                            entry: vm.fetchTodayEntry(),
                            streak: vm.currentStreak,
                            animateIn: animateIn
                        )
                        .padding(.horizontal, 16)
                    }

                    // [E] Reflection Peek
                    if let vm = viewModel {
                        ReflectionPeekCard(
                            entry: vm.fetchTodayEntry(),
                            animateIn: animateIn
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(backgroundGradient)
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
            if !animateIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateIn = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Text(Date().shortFormatted)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if let entry = viewModel?.fetchTodayEntry(),
                   let city = entry.city {
                    Text("·")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(city)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : -10)
        .animation(.easeOut(duration: 0.5), value: animateIn)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let moodColor: Color = {
            if let entry = viewModel?.fetchTodayEntry(), viewModel?.hasSubmittedData == true {
                return Color.moodGradient(for: entry.feeling)
            }
            return Color.gray
        }()

        return LinearGradient(
            colors: [
                moodColor.opacity(0.15),
                Color.black.opacity(0.95),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Greeting

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
}

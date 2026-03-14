import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingGuidedFlow = false
    @State private var viewModel: DailyEntryViewModel?
    @State private var animateIn = false
    @State private var isUpdatingLocation = false
    @State private var todayEntry: DailyEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // [A] Header
                    headerSection

                    // [B] Hero — Mood Orb
                    MoodOrbView(
                        entry: todayEntry,
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
                            entry: todayEntry,
                            streak: vm.currentStreak,
                            animateIn: animateIn
                        )
                        .padding(.horizontal, 16)
                    }

                    // [E] Reflection Peek
                    ReflectionPeekCard(
                        entry: todayEntry,
                        animateIn: animateIn
                    )
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background {
                backgroundGradient
            }
            .cosmicBackground()
            .fullScreenCover(isPresented: $showingGuidedFlow) {
                GuidedPromptFlowView()
            }
            .onChange(of: NavigationState.shared.showGuidedPrompt) { _, shouldShow in
                if shouldShow {
                    showingGuidedFlow = true
                    NavigationState.shared.showGuidedPrompt = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        try? await Task.sleep(for: .seconds(4))
                        viewModel?.checkForTodayEntry()
                        todayEntry = viewModel?.fetchTodayEntry()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .screenTimeDidUpdate)) { _ in
                viewModel?.checkForTodayEntry()
                todayEntry = viewModel?.fetchTodayEntry()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openGuidedPrompt)) { _ in
                showingGuidedFlow = true
            }
            .onChange(of: showingGuidedFlow) { _, newValue in
                if !newValue {
                    viewModel?.checkForTodayEntry()
                    todayEntry = viewModel?.fetchTodayEntry()
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DailyEntryViewModel(modelContext: modelContext)
            } else {
                viewModel?.checkForTodayEntry()
            }
            todayEntry = viewModel?.fetchTodayEntry()
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

                Text("\u{00B7}")
                    .foregroundStyle(.secondary)

                locationCapsule
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : -10)
        .animation(.easeOut(duration: 0.5), value: animateIn)
    }

    // MARK: - Location Capsule

    private var locationCapsule: some View {
        Button {
            Task {
                isUpdatingLocation = true
                defer { isUpdatingLocation = false }
                try? await viewModel?.updateLocation()
                todayEntry = viewModel?.fetchTodayEntry()
            }
        } label: {
            HStack(spacing: 4) {
                if isUpdatingLocation {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.secondary)
                } else if let city = todayEntry?.city {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(city)
                        .font(.subheadline)
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                } else {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text("Add location")
                        .font(.subheadline)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
        }
        .disabled(isUpdatingLocation)
        .accessibilityLabel(isUpdatingLocation ? "Updating location" : (todayEntry?.city ?? "Add location"))
        .accessibilityHint("Double tap to update your current location")
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let moodColor: Color = {
            if let entry = todayEntry, viewModel?.hasSubmittedData == true {
                return Color.moodGradient(for: entry.feeling)
            }
            return Color.gray
        }()

        return LinearGradient(
            colors: [
                moodColor.opacity(0.15),
                Color.clear
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

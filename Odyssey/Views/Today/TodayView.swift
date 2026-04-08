import SwiftData
import SwiftUI

enum TodayDrillDown: Hashable {
    case streak
    case map
}

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingGuidedFlow = false
    @State private var guidedFlowDate: Date?
    @State private var viewModel: DailyEntryViewModel?
    @State private var insightsViewModel: InsightsViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var animateIn = false
    @State private var isUpdatingLocation = false
    @State private var todayEntry: DailyEntry?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // [A] Header
                    headerSection

                    // [B] Hero — Mood Orb
                    MoodOrbView(
                        entry: todayEntry,
                        hasEntry: viewModel?.hasSubmittedData ?? false,
                        onBeginEntry: {
                            guidedFlowDate = nil
                            showingGuidedFlow = true
                        },
                        onTapOrb: { navigationPath.append(MetricDefinition.mood) },
                        animateIn: animateIn
                    )

                    // [C] Week Pulse
                    if let vm = viewModel {
                        WeekPulseView(
                            weekEntries: vm.fetchWeekEntries(),
                            onTapEntry: { entry in navigationPath.append(entry) },
                            onTapEmptyDay: { date in
                                guidedFlowDate = date
                                showingGuidedFlow = true
                            },
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
                            screenTimeFallback: SharedDefaults.getScreenTime()?.seconds,
                            onTapVital: { vital in
                                switch vital {
                                case .steps: navigationPath.append(MetricDefinition.steps)
                                case .sleep: navigationPath.append(MetricDefinition.sleepHours)
                                case .workout: navigationPath.append(MetricDefinition.workoutMinutes)
                                case .screenTime: navigationPath.append(MetricDefinition.screenTime)
                                case .streak: navigationPath.append(TodayDrillDown.streak)
                                }
                            },
                            animateIn: animateIn
                        )
                        .padding(.horizontal, 16)
                    }

                    // [E] Reflection Peek
                    ReflectionPeekCard(
                        entry: todayEntry,
                        onTap: {
                            if let entry = todayEntry {
                                navigationPath.append(entry)
                            }
                        },
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
            .navigationDestination(for: MetricDefinition.self) { metric in
                if let ivm = insightsViewModel {
                    MetricDetailView(metric: metric, viewModel: ivm)
                }
            }
            .navigationDestination(for: DailyEntry.self) { entry in
                JournalEntryDetailView(entry: entry)
            }
            .navigationDestination(for: TodayDrillDown.self) { destination in
                switch destination {
                case .streak:
                    if let ivm = insightsViewModel {
                        StreakView(
                            currentStreak: ivm.currentStreak,
                            longestStreak: ivm.longestStreak,
                            entries: ivm.entries
                        )
                    }
                case .map:
                    if let vm = viewModel {
                        MapVisualizationView(entries: vm.fetchAllEntries())
                    }
                }
            }
            #if os(macOS)
            .sheet(isPresented: $showingGuidedFlow) {
                GuidedPromptFlowView(entryDate: guidedFlowDate)
                    .frame(minWidth: 520, idealWidth: 650, maxWidth: 750,
                           minHeight: 620, idealHeight: 750, maxHeight: 850)
            }
            #else
            .fullScreenCover(isPresented: $showingGuidedFlow) {
                        GuidedPromptFlowView(entryDate: guidedFlowDate)
                    }
            #endif
                    .onChange(of: NavigationState.shared.showGuidedPrompt) { _, shouldShow in
                        if shouldShow {
                            guidedFlowDate = nil
                            showingGuidedFlow = true
                            NavigationState.shared.showGuidedPrompt = false
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            viewModel?.checkForTodayEntry()
                            todayEntry = viewModel?.fetchTodayEntry()
                            insightsViewModel?.loadEntries()
                        }
                    }
            #if os(iOS)
                    .onReceive(NotificationCenter.default.publisher(for: .screenTimeDidUpdate)) { _ in
                        viewModel?.checkForTodayEntry()
                        todayEntry = viewModel?.fetchTodayEntry()
                        insightsViewModel?.loadEntries()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .snapshotDidUpdate)) { _ in
                        viewModel?.checkForTodayEntry()
                        todayEntry = viewModel?.fetchTodayEntry()
                        insightsViewModel?.loadEntries()
                    }
            #endif
                    .onReceive(NotificationCenter.default.publisher(for: .openGuidedPrompt)) { _ in
                        guidedFlowDate = nil
                        showingGuidedFlow = true
                    }
                    .onChange(of: showingGuidedFlow) { _, newValue in
                        if !newValue {
                            viewModel?.checkForTodayEntry()
                            todayEntry = viewModel?.fetchTodayEntry()
                            insightsViewModel?.loadEntries()
                        }
                    }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DailyEntryViewModel(modelContext: modelContext)
            } else {
                viewModel?.checkForTodayEntry()
            }
            if insightsViewModel == nil {
                insightsViewModel = InsightsViewModel(modelContext: modelContext)
            }
            insightsViewModel?.loadEntries()
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

    @ViewBuilder
    private var locationCapsule: some View {
        if isUpdatingLocation {
            capsuleLabel {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.secondary)
            }
        } else if todayEntry?.city != nil {
            Button {
                navigationPath.append(TodayDrillDown.map)
            } label: {
                capsuleLabel {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(todayEntry?.city ?? "")
                        .font(.subheadline)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
            }
            .accessibilityLabel(todayEntry?.city ?? "Location")
            .accessibilityHint("Double tap to view your location map")
        } else {
            Button {
                Task {
                    isUpdatingLocation = true
                    defer { isUpdatingLocation = false }
                    try? await viewModel?.updateLocation()
                    todayEntry = viewModel?.fetchTodayEntry()
                }
            } label: {
                capsuleLabel {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text("Add location")
                        .font(.subheadline)
                }
            }
            .accessibilityLabel("Add location")
            .accessibilityHint("Double tap to capture your current location")
        }
    }

    private func capsuleLabel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
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
        case 0 ..< 12: return "Good Morning"
        case 12 ..< 17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
}

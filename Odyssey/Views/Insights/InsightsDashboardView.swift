import SwiftData
import SwiftUI

struct InsightsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: InsightsViewModel?
    @State private var showWeeklyReports = false
    @Bindable private var navigationState = NavigationState.shared

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    InsightsTabContainerView(viewModel: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Insights")
            .cosmicBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WeeklyReportsView()
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(Color.accentAmber)
                    }
                    .accessibilityLabel("Weekly Reports")
                    .accessibilityHint("View past weekly digest summaries")
                }
            }
            .navigationDestination(isPresented: $showWeeklyReports) {
                WeeklyReportsView()
            }
        }
        .onChange(of: navigationState.showWeeklyReports) { _, newValue in
            if newValue {
                showWeeklyReports = true
                navigationState.showWeeklyReports = false
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InsightsViewModel(modelContext: modelContext)
            }
            viewModel?.loadEntries()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    viewModel?.loadEntries()
                }
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: .screenTimeDidUpdate)) { _ in
            viewModel?.loadEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapshotDidUpdate)) { _ in
            viewModel?.loadEntries()
        }
        #endif
    }
}

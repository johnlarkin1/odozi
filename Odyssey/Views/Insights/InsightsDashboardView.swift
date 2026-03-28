import SwiftData
import SwiftUI

struct InsightsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: InsightsViewModel?

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
        #endif
    }
}

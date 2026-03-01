import SwiftUI
import SwiftData

struct InsightsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
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
    }
}

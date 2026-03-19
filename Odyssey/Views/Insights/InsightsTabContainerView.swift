import SwiftUI

struct InsightsTabContainerView: View {
    @Bindable var viewModel: InsightsViewModel
    @State private var selectedTab: InsightsTab = .overview

    var body: some View {
        VStack(spacing: 12) {
            InsightsTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 16)

            DateRangePicker(selection: Binding(
                get: { viewModel.dateRange },
                set: { viewModel.dateRange = $0 }
            ))

            TabView(selection: $selectedTab) {
                OverviewTabView(viewModel: viewModel)
                    .tag(InsightsTab.overview)

                MindTabView(viewModel: viewModel)
                    .tag(InsightsTab.mind)

                BodyTabView(viewModel: viewModel)
                    .tag(InsightsTab.body)

                WorldTabView(viewModel: viewModel)
                    .tag(InsightsTab.world)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
        }
    }
}

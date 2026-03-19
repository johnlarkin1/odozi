import SwiftUI

struct MacMainView: View {
    @State private var selectedSection: SidebarSection = .today

    enum SidebarSection: String, CaseIterable, Identifiable {
        case today = "Today"
        case journal = "Journal"
        case insights = "Insights"
        case profile = "Profile"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: "sun.max.fill"
            case .journal: "book.fill"
            case .insights: "chart.line.uptrend.xyaxis"
            case .profile: "person.crop.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Odyssey")
            .listStyle(.sidebar)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cosmicBackground()
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .today:
            TodayView()
        case .journal:
            JournalView()
        case .insights:
            InsightsDashboardView()
        case .profile:
            ProfileView()
        }
    }
}

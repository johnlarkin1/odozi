import SwiftUI

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

    /// Sections shown in the macOS sidebar (excludes Profile — settings go to Cmd+,)
    static var macCases: [SidebarSection] {
        [.today, .journal, .insights]
    }
}

struct MacMainView: View {
    @Binding var selectedSection: SidebarSection
    @Binding var showGuidedPrompt: Bool

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.macCases, selection: $selectedSection) { section in
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
        .onChange(of: showGuidedPrompt) { _, shouldShow in
            if shouldShow {
                // Drive the guided prompt via NavigationState so TodayView picks it up
                NavigationState.shared.showGuidedPrompt = true
                showGuidedPrompt = false
            }
        }
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
            // Shouldn't appear in macOS sidebar, but handle gracefully
            ProfileView()
        }
    }
}

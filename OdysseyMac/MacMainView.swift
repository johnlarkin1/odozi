import SwiftData
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case journal = "Journal"
    case explore = "Explore"
    case insights = "Insights"
    case profile = "Profile"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: "sun.max.fill"
        case .journal: "book.fill"
        case .explore: "globe.desk.fill"
        case .insights: "chart.line.uptrend.xyaxis"
        case .profile: "person.crop.circle"
        }
    }

    var sidebarGroup: String {
        switch self {
        case .today: "Daily"
        case .journal: "Library"
        case .explore: "Explore"
        case .insights: "Analytics"
        case .profile: "Settings"
        }
    }

    /// Sections shown in the macOS sidebar (excludes Profile — settings go to Cmd+,)
    static var macCases: [SidebarSection] {
        [.today, .journal, .explore, .insights]
    }
}

struct MacMainView: View {
    @Binding var selectedSection: SidebarSection
    @Binding var showGuidedPrompt: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("Odozi")
                .listStyle(.sidebar)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cosmicBackground()
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        detailToolbar
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .onChange(of: showGuidedPrompt) { _, shouldShow in
            if shouldShow {
                NavigationState.shared.showGuidedPrompt = true
                showGuidedPrompt = false
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selectedSection) {
            Section("Daily") {
                sidebarRow(for: .today)
            }

            Section("Library") {
                sidebarRow(for: .journal)
            }

            Section("Explore") {
                sidebarRow(for: .explore)
            }

            Section("Analytics") {
                sidebarRow(for: .insights)
            }
        }
    }

    private func sidebarRow(for section: SidebarSection) -> some View {
        Label {
            Text(section.rawValue)
        } icon: {
            Image(systemName: section.icon)
                .foregroundStyle(sidebarIconColor(for: section))
        }
        .tag(section)
    }

    private func sidebarIconColor(for section: SidebarSection) -> Color {
        switch section {
        case .today: .accentAmber
        case .journal: .accentTeal
        case .explore: .accentTeal
        case .insights: .cosmicPurple
        case .profile: .secondary
        }
    }

    // MARK: - Detail Toolbar

    @ViewBuilder
    private var detailToolbar: some View {
        switch selectedSection {
        case .today:
            Button {
                NavigationState.shared.showGuidedPrompt = true
            } label: {
                Label("New Entry", systemImage: "plus.circle.fill")
            }
            .help("Start a new journal entry (⌘N)")
        case .journal:
            EmptyView()
        case .explore:
            EmptyView()
        case .insights:
            EmptyView()
        case .profile:
            EmptyView()
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .today:
            TodayView()
        case .journal:
            JournalView()
        case .explore:
            ExploreTabView()
        case .insights:
            InsightsDashboardView()
        case .profile:
            ProfileView()
        }
    }
}

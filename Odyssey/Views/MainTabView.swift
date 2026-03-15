import SwiftUI

struct MainTabView: View {
    @Bindable private var navigationState = NavigationState.shared

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            TodayView()
                .tag(NavigationState.Tab.today)
                .tabItem {
                    Image(systemName: "sun.max.fill")
                    Text("Today")
                }

            JournalView()
                .tag(NavigationState.Tab.journal)
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Journal")
                }

            InsightsDashboardView()
                .tag(NavigationState.Tab.insights)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Insights")
                }

            ProfileView()
                .tag(NavigationState.Tab.profile)
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
        .tint(Color.accentAmber)
        .toolbarBackground(Color.deepSpaceBlue.opacity(0.85), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

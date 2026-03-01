import SwiftUI

struct InsightsTabBar: View {
    @Binding var selectedTab: InsightsTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(InsightsTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.cosmicPurple.opacity(0.3))
                                .matchedGeometryEffect(id: "tab_indicator", in: tabNamespace)
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.cardSurface))
    }
}

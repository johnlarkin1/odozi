import SwiftUI

struct InsightsTabBar: View {
    @Binding var selectedTab: InsightsTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(InsightsTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.cardSurface))
    }

    private func tabButton(for tab: InsightsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.rawValue)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.cosmicPurple.opacity(0.3))
                        .matchedGeometryEffect(id: "tab_indicator", in: tabNamespace)
                }
            }
            .foregroundStyle(isSelected ? .white : .secondary)
        }
    }
}

import SwiftData
import SwiftUI

struct AchievementGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var grouped: [String: [Achievement]] = [:]

    private let categoryOrder = ["streak", "first", "depth", "exploration", "wellness"]
    private let categoryTitles: [String: String] = [
        "streak": "Streak Milestones",
        "first": "First Steps",
        "depth": "Going Deeper",
        "exploration": "Explorer",
        "wellness": "Wellness"
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryHeader

                ForEach(categoryOrder, id: \.self) { category in
                    if let achievements = grouped[category], !achievements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(categoryTitles[category] ?? category.capitalized)
                                .font(.headline)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(achievements.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { achievement in
                                    AchievementBadgeCell(achievement: achievement)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .navigationTitle("Achievements")
        .cosmicBackground()
        .onAppear {
            loadAchievements()
            markAllSeen()
        }
    }

    private var summaryHeader: some View {
        let total = grouped.values.flatMap { $0 }
        let unlocked = total.filter(\.isUnlocked).count
        return VStack(spacing: 8) {
            Text("\(unlocked) / \(total.count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentAmber)
            Text("achievements unlocked")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func loadAchievements() {
        let service = AchievementService(modelContext: modelContext)
        grouped = service.fetchAll()
    }

    private func markAllSeen() {
        let service = AchievementService(modelContext: modelContext)
        service.markAllSeen()
    }
}

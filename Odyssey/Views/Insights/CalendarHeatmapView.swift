import SwiftUI

struct CalendarHeatmapView: View {
    let entries: [DailyEntry]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity Heatmap")
                    .font(.title2.bold())
                    .padding(.horizontal, 16)

                // Day labels
                HStack(spacing: 4) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(heatmapDays(), id: \.date) { day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.color)
                            .frame(height: 16)
                            .accessibilityLabel(day.accessibilityDescription)
                    }
                }
                .padding(.horizontal, 16)

                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach([0.1, 0.3, 0.5, 0.7, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentAmber.opacity(opacity))
                            .frame(width: 12, height: 12)
                    }
                    Text("More")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
        .cosmicBackground()
        .navigationTitle("Heatmap")
    }

    private struct HeatmapDay {
        let date: Date
        let color: Color
        let hasEntry: Bool
        let moodScore: Int?

        var accessibilityDescription: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let dateStr = formatter.string(from: date)
            if hasEntry, let score = moodScore {
                return "\(dateStr), mood \(score) out of 10"
            }
            return "\(dateStr), no entry"
        }
    }

    private func heatmapDays() -> [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -364, to: today) else { return [] }

        // Align to Sunday
        let weekday = calendar.component(.weekday, from: start)
        guard let alignedStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: start) else { return [] }

        let entryMap = Dictionary(uniqueKeysWithValues: entries.map {
            (calendar.startOfDay(for: $0.date), $0)
        })

        var days: [HeatmapDay] = []
        var current = alignedStart
        while current <= today {
            if let entry = entryMap[current], entry.hasPromptData {
                let mood = entry.feeling ?? 5
                let intensity = Double(mood) / 10.0
                let color = Color.accentAmber.opacity(max(0.15, intensity))
                days.append(HeatmapDay(date: current, color: color, hasEntry: true, moodScore: mood))
            } else {
                days.append(HeatmapDay(date: current, color: Color.white.opacity(0.05), hasEntry: false, moodScore: nil))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }
}

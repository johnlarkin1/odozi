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
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
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
        .background(Color.black)
        .navigationTitle("Heatmap")
    }

    private struct HeatmapDay {
        let date: Date
        let color: Color
    }

    private func heatmapDays() -> [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -364, to: today)!

        // Align to Sunday
        let weekday = calendar.component(.weekday, from: start)
        let alignedStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: start)!

        let entryMap = Dictionary(uniqueKeysWithValues: entries.map {
            (calendar.startOfDay(for: $0.date), $0)
        })

        var days: [HeatmapDay] = []
        var current = alignedStart
        while current <= today {
            if let entry = entryMap[current], entry.hasPromptData {
                let intensity = Double(entry.feeling) / 10.0
                days.append(HeatmapDay(date: current, color: Color.accentAmber.opacity(max(0.15, intensity))))
            } else {
                days.append(HeatmapDay(date: current, color: Color.white.opacity(0.05)))
            }
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }
}

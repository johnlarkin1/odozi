import SwiftUI
import Charts

struct StreakView: View {
    let currentStreak: Int
    let longestStreak: Int
    let entries: [DailyEntry]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current streak
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentAmber)

                    Text("\(currentStreak)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Current Streak")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Stats
                HStack(spacing: 16) {
                    statCard("Longest", value: "\(longestStreak) days", color: .accentAmber)
                    statCard("Total Entries", value: "\(entries.filter { $0.hasPromptData }.count)", color: .accentTeal)
                }
                .padding(.horizontal, 16)

                // Monthly completions chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly Completions")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    Chart(monthlyData, id: \.month) { data in
                        BarMark(
                            x: .value("Month", data.month),
                            y: .value("Entries", data.count)
                        )
                        .foregroundStyle(Color.accentAmber.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 32)
            }
        }
        .navigationTitle("Streaks")
        .cosmicBackground()
    }

    private var monthlyData: [(month: String, count: Int)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var monthly: [String: Int] = [:]
        for entry in entries where entry.hasPromptData {
            let key = formatter.string(from: entry.date)
            monthly[key, default: 0] += 1
        }

        // Last 6 months
        let now = Date()
        return (0..<6).reversed().compactMap { monthsAgo in
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { return nil }
            let key = formatter.string(from: date)
            return (key, monthly[key] ?? 0)
        }
    }

    private func statCard(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .fontDesign(.rounded)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardSurface))
    }
}

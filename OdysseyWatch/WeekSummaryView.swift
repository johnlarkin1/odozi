import SwiftData
import SwiftUI

struct WeekSummaryView: View {
    @Query(filter: #Predicate<DailyEntry> { _ in true },
           sort: \DailyEntry.date,
           order: .reverse)
    private var allEntries: [DailyEntry]

    private var weekEntries: [DailyEntry] {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) else {
            return []
        }
        return allEntries
            .filter { $0.date >= weekAgo && $0.hasUserSubmitted }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("This Week")
                    .font(.headline)

                if weekEntries.isEmpty {
                    Text("No entries yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // 7-day mood bar chart
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(last7Days(), id: \.self) { date in
                            let entry = weekEntries.first {
                                Calendar.current.isDate($0.date, inSameDayAs: date)
                            }
                            VStack(spacing: 2) {
                                if let entry {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.moodGradient(for: entry.feeling))
                                        .frame(height: CGFloat(entry.feeling) * 4)
                                } else {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.cardSurface)
                                        .frame(height: 4)
                                }
                                Text(dayLabel(date))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 60)

                    // Summary stats
                    let avgMood = weekEntries.map(\.feeling).reduce(0, +) / max(weekEntries.count, 1)
                    HStack {
                        StatBubble(label: "Avg", value: "\(avgMood)/10")
                        StatBubble(label: "Days", value: "\(weekEntries.count)/7")
                    }

                    if let steps = weekEntries.compactMap(\.stepCount).last {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("\(steps) steps today")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(.black.gradient, for: .tabView)
    }

    private func last7Days() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let label = formatter.string(from: date)
        return String(label.prefix(1))
    }
}

private struct StatBubble: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

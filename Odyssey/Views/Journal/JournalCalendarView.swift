import SwiftUI

struct JournalCalendarView: View {
    let entries: [DailyEntry]
    @Binding var selectedDate: Date

    @State private var displayedMonth = Date()

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    if let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(displayedMonth.monthYear)
                    .font(.headline)

                Spacer()

                Button {
                    if let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            // Day headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Calendar days
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        let entry = entryFor(date)
                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(date.dayNumber)")
                                    .font(.caption)
                                    .foregroundStyle(Calendar.current.isDateInToday(date) ? Color.accentAmber : .white)

                                Circle()
                                    .fill(entry.map { Color.moodGradient(for: $0.feeling) } ?? Color.clear)
                                    .frame(width: 6, height: 6)
                            }
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.white.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding(4)
        .onAppear {
            displayedMonth = selectedDate
        }
        .onChange(of: selectedDate) { _, newValue in
            let calendar = Calendar.current
            if !calendar.isDate(displayedMonth, equalTo: newValue, toGranularity: .month) {
                displayedMonth = newValue
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    private func entryFor(_ date: Date) -> DailyEntry? {
        entries.first { $0.hasPromptData && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

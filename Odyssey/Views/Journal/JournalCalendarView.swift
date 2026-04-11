import SwiftUI

struct JournalCalendarView: View {
    let entries: [DailyEntry]
    @Binding var selectedDate: Date
    var onTapEntry: ((DailyEntry) -> Void)?
    var onTapEmptyDate: ((Date) -> Void)?

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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            // Day headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
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
                        let isEmptyPastDate = entry == nil && isPastDate(date)

                        Button {
                            if let entry = entry, let tapEntry = onTapEntry {
                                tapEntry(entry)
                            } else if isEmptyPastDate, let tapEmpty = onTapEmptyDate {
                                tapEmpty(date)
                            } else {
                                selectedDate = date
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(date.dayNumber)")
                                    .font(.caption)
                                    .foregroundStyle(Calendar.current.isDateInToday(date) ? Color.accentAmber : .white)

                                ZStack {
                                    // User-journaled → filled mood dot.
                                    // Auto-captured only → amber ring (matches the WeekPulseView convention).
                                    // Empty past → faint outline.
                                    if let entry = entry, entry.hasUserSubmitted {
                                        Circle()
                                            .fill(Color.moodGradient(for: entry.feeling))
                                            .frame(width: 6, height: 6)

                                        if !entry.wasCompletedOnDay {
                                            Circle()
                                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                                .foregroundStyle(Color.white.opacity(0.5))
                                                .frame(width: 10, height: 10)
                                        }
                                    } else if entry != nil {
                                        // Auto-captured only
                                        Circle()
                                            .strokeBorder(Color.accentAmber, lineWidth: 1)
                                            .frame(width: 8, height: 8)
                                    } else if isEmptyPastDate && onTapEmptyDate != nil {
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                            .frame(width: 6, height: 6)
                                    }
                                }
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
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else {
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
        // Return any entry for this date — including auto-captured entries
        // with only background data. Cell rendering distinguishes journaled
        // vs auto-captured visually.
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func isPastDate(_ date: Date) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        return target < today
    }
}

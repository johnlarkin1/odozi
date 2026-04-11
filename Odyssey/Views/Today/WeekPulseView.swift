import SwiftUI

struct WeekPulseView: View {
    let weekEntries: [DailyEntry?]
    var onTapEntry: ((DailyEntry) -> Void)?
    var onTapEmptyDay: ((Date) -> Void)?
    var animateIn: Bool = false

    @State private var dotsVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("This Week")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                ForEach(0 ..< 7, id: \.self) { index in
                    let date = Date().daysAgo(6 - index)
                    let entry = weekEntries[index]
                    let isToday = index == 6
                    let isPast = !isToday

                    if let entry = entry, onTapEntry != nil {
                        Button {
                            onTapEntry?(entry)
                        } label: {
                            dayContent(entry: entry, isToday: isToday, index: index, date: date)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    } else if entry == nil, isPast, onTapEmptyDay != nil {
                        Button {
                            onTapEmptyDay?(date)
                        } label: {
                            dayContent(entry: nil, isToday: false, index: index, date: date)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    } else {
                        dayContent(entry: entry, isToday: isToday, index: index, date: date)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
        )
        .onChange(of: animateIn) { _, newValue in
            if newValue {
                withAnimation {
                    dotsVisible = true
                }
            }
        }
    }

    private func dayContent(entry: DailyEntry?, isToday: Bool, index: Int, date: Date) -> some View {
        let isPast = !isToday && !Calendar.current.isDateInToday(date)
        return VStack(spacing: 6) {
            ZStack {
                if let entry = entry, entry.hasUserSubmitted {
                    Circle()
                        .fill(Color.moodGradient(for: entry.feeling))
                        .frame(width: 32, height: 32)

                    if !entry.wasCompletedOnDay {
                        Circle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                    }
                } else if entry != nil {
                    // Auto-captured day: background data exists but the user
                    // hasn't journaled. Amber ring + a tiny sparkles glyph makes
                    // this visually distinct from an untouched empty day.
                    ZStack {
                        Circle()
                            .strokeBorder(Color.accentAmber, lineWidth: 2)
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.accentAmber)
                    }
                } else if isPast && onTapEmptyDay != nil {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                } else {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                if isToday {
                    Circle()
                        .strokeBorder(Color.accentAmber, lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
            }
            .scaleEffect(dotsVisible ? 1 : 0)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7)
                    .delay(Double(index) * 0.05),
                value: dotsVisible
            )

            Text(dayLetter(for: date))
                .font(.caption2)
                .foregroundStyle(isToday ? .white : .secondary)
        }
    }

    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}

import SwiftUI

struct WeekPulseView: View {
    let weekEntries: [DailyEntry?]
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

                    VStack(spacing: 6) {
                        ZStack {
                            if let entry = entry {
                                Circle()
                                    .fill(Color.moodGradient(for: entry.feeling))
                                    .frame(width: 32, height: 32)
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
                    .frame(maxWidth: .infinity)
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

    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}

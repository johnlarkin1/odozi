import SwiftUI

struct ReviewBestDayCard: View {
    let entry: DailyEntry?

    var body: some View {
        ZStack {
            if let entry = entry {
                LinearGradient(
                    colors: [entry.feelingColor.opacity(0.3), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    Text("Your Best Day")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("\(entry.feeling)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.moodGradientColor)

                    Text(entry.date.shortFormatted)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("out of 10")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if !entry.journalEntry.isEmpty {
                        Text("\"\(String(entry.journalEntry.prefix(120)))...\"")
                            .font(.body.italic())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                    Spacer()
                }
            } else {
                Color.black.ignoresSafeArea()
                Text("No entries yet")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

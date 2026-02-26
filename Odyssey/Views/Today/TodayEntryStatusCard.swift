import SwiftUI

struct TodayEntryStatusCard: View {
    let hasEntry: Bool
    let entry: DailyEntry?
    let onBeginEntry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if hasEntry, let entry = entry {
                // Completed state
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.successGreen)
                            Text("Today's Entry Complete")
                                .font(.headline)
                        }

                        Text("Mood: \(entry.moodEmoji) \(entry.feeling)/10")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !entry.singleWordFeeling.isEmpty {
                            Text("Feeling: \(entry.singleWordFeeling)")
                                .font(.subheadline)
                                .foregroundStyle(entry.feelingColor)
                        }
                    }
                    Spacer()
                }

                Button(action: onBeginEntry) {
                    Text("Edit Entry")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                // Not started state
                VStack(spacing: 12) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentAmber)

                    Text("How's your day going?")
                        .font(.title3.bold())

                    Text("Take a few minutes to reflect")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: onBeginEntry) {
                        Text("Begin Today's Entry")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
        )
    }
}

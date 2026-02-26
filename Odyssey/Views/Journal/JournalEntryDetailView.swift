import SwiftUI

struct JournalEntryDetailView: View {
    let entry: DailyEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.date.dayOfWeek)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(entry.date.shortFormatted)
                        .font(.largeTitle.bold())
                }
                .padding(.horizontal, 16)

                // Mood & Feeling
                HStack(spacing: 16) {
                    detailCard(title: "Mood", value: "\(entry.moodEmoji) \(entry.feeling)/10", color: entry.moodGradientColor)
                    detailCard(title: "Sleep", value: "\(entry.sleepQuality)/10", color: .accentTeal)
                }
                .padding(.horizontal, 16)

                if !entry.singleWordFeeling.isEmpty {
                    sectionCard(title: "Feeling", icon: "paintpalette") {
                        Text(entry.singleWordFeeling)
                            .font(.title3.bold())
                            .foregroundStyle(entry.feelingColor)
                    }
                }

                if !entry.gratitude.isEmpty {
                    sectionCard(title: "Gratitude", icon: "heart.fill") {
                        Text(entry.gratitude)
                            .font(.body)
                    }
                }

                if !entry.win.isEmpty {
                    sectionCard(title: "Win", icon: "trophy.fill") {
                        Text(entry.win)
                            .font(.body)
                    }
                }

                if !entry.tension.isEmpty {
                    sectionCard(title: "Tension", icon: "cloud.fill") {
                        Text(entry.tension)
                            .font(.body)
                    }
                }

                if !entry.journalEntry.isEmpty {
                    sectionCard(title: "Journal", icon: "note.text") {
                        Text(entry.journalEntry)
                            .font(.body)
                    }
                }

                if entry.drinks > 0 {
                    sectionCard(title: "Drinks", icon: "wineglass") {
                        Text("\(entry.drinks)")
                            .font(.title2.bold())
                    }
                }

                // Background data
                if entry.stepCount != nil || entry.screenTimeSeconds != nil || entry.latitude != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Background Data")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            if let steps = entry.stepCount {
                                miniStatCard(icon: "figure.walk", value: "\(steps)", label: "Steps")
                            }
                            if entry.screenTimeSeconds != nil {
                                miniStatCard(icon: "iphone", value: entry.screenTimeFormatted, label: "Screen Time")
                            }
                            if entry.latitude != nil {
                                miniStatCard(icon: "location.fill", value: entry.locationDisplay, label: "Location")
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardSurface))
    }

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentAmber)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardSurface))
        .padding(.horizontal, 16)
    }

    private func miniStatCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentTeal)
            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
    }
}

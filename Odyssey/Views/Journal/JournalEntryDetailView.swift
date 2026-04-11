import SwiftData
import SwiftUI

/// Canonical detail surface for any day — user-journaled, auto-captured only,
/// or entirely empty. Presents stats (mood, sleep, background data) and a
/// context-aware CTA that opens `GuidedPromptFlowView` to add/edit journal
/// content for the day.
struct JournalEntryDetailView: View {
    private let entry: DailyEntry?
    private let placeholderDate: Date?

    @Environment(\.modelContext) private var modelContext
    @State private var showingGuidedFlow = false

    init(entry: DailyEntry) {
        self.entry = entry
        placeholderDate = nil
    }

    /// Use this initializer for days that have no `DailyEntry` yet — the view
    /// renders a placeholder body and a "Start entry" CTA.
    init(date: Date) {
        entry = nil
        placeholderDate = date
    }

    private var displayDate: Date {
        entry?.date ?? placeholderDate ?? Date()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                editCTA

                if let entry = entry {
                    entryBody(entry)
                } else {
                    emptyPlaceholder
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .cosmicBackground()
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .sheet(isPresented: $showingGuidedFlow) {
            GuidedPromptFlowView(entryDate: displayDate)
                .frame(minWidth: 520, idealWidth: 650, maxWidth: 750,
                       minHeight: 620, idealHeight: 750, maxHeight: 850)
        }
        #else
        .fullScreenCover(isPresented: $showingGuidedFlow) {
                    GuidedPromptFlowView(entryDate: displayDate)
                }
        #endif
    }

    // MARK: - Header + Badges

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayDate.dayOfWeek)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(displayDate.shortFormatted)
                .font(.largeTitle.bold())

            sourceBadges
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var sourceBadges: some View {
        if let entry = entry {
            HStack(spacing: 8) {
                if entry.hasUserSubmitted {
                    badge(
                        label: "Journaled",
                        systemImage: "pencil.and.outline",
                        tint: .accentAmber
                    )
                }
                if entry.hasAutoData {
                    badge(
                        label: "Auto-captured",
                        systemImage: "sparkles",
                        tint: .accentTeal
                    )
                }
                if entry.hasUserSubmitted && !entry.wasCompletedOnDay {
                    Text("Added later")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
    }

    private func badge(label: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(tint.opacity(0.35), lineWidth: 0.5)
        )
    }

    // MARK: - Edit CTA

    private var editCTA: some View {
        Button {
            showingGuidedFlow = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: ctaIcon)
                    .font(.subheadline.weight(.semibold))
                Text(ctaLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentAmber.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentAmber.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel(ctaLabel)
        .accessibilityHint("Double tap to open the guided journal flow")
    }

    private var ctaLabel: String {
        guard let entry = entry else { return "Start entry" }
        if entry.hasUserSubmitted { return "Edit entry" }
        if entry.hasAutoData { return "Add journal details" }
        return "Start entry"
    }

    private var ctaIcon: String {
        guard let entry = entry else { return "square.and.pencil" }
        if entry.hasUserSubmitted { return "pencil" }
        return "square.and.pencil"
    }

    // MARK: - Placeholder (no entry)

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No data captured for this day")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Tap \u{201C}Start entry\u{201D} to journal how this day went.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardSurface))
        .padding(.horizontal, 16)
    }

    // MARK: - Entry body

    @ViewBuilder
    private func entryBody(_ entry: DailyEntry) -> some View {
        // Mood & Feeling
        HStack(spacing: 16) {
            if entry.feeling > 0 {
                detailCard(title: "Mood", value: "\(entry.feeling)/10", color: entry.moodGradientColor)
            }
            if entry.sleepQuality > 0 {
                detailCard(title: "Sleep", value: "\(entry.sleepQuality)/10", color: .accentTeal)
            }
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
        if entry.stepCount != nil || entry.screenTimeSeconds != nil || entry.latitude != nil || entry.didWorkout || entry
            .hasSleepStageData {
            backgroundDataSection(entry)
        }

        // Photo map toggle
        if entry.hasPhotos {
            photoMapToggle(entry)
        }
    }

    @ViewBuilder
    private func backgroundDataSection(_ entry: DailyEntry) -> some View {
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
                if entry.didWorkout {
                    miniStatCard(icon: "figure.run", value: entry.totalWorkoutFormatted, label: entry.primaryWorkoutType)
                }
                if entry.latitude != nil {
                    miniStatCard(icon: "location.fill", value: entry.locationDisplay, label: "Location")
                }
            }
            .padding(.horizontal, 16)

            // Workout breakdown
            if entry.didWorkout {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Workouts")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if let intensity = entry.workoutIntensityLabel {
                            Text("Intensity: \(intensity)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(entry.workouts) { workout in
                        HStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .foregroundStyle(Color.successGreen)
                                .frame(width: 16)
                            Text(workout.activityName)
                                .font(.caption.bold())
                            Spacer()
                            Text(formatWorkoutDuration(workout.durationSeconds))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let cal = workout.totalCalories {
                                Text("\(Int(cal)) kcal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Sleep stage breakdown
            if entry.hasSleepStageData {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sleep Stages")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if let hours = entry.sleepHours {
                            Text(String(format: "%.1fh total", hours))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let score = entry.sleepScore, let label = entry.sleepScoreLabel {
                            Text("Score: \(score) (\(label))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    SleepStageBar(stages: entry.sleepStageBreakdown)
                    HStack(spacing: 8) {
                        ForEach(entry.sleepStageBreakdown, id: \.label) { stage in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(stage.color)
                                    .frame(width: 6, height: 6)
                                Text("\(stage.label) \(String(format: "%.1fh", stage.hours))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func photoMapToggle(_ entry: DailyEntry) -> some View {
        HStack {
            Label("Show on Photo Map", systemImage: "map.fill")
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { entry.showOnPhotoMap },
                set: { newValue in
                    if newValue, entry.mapThumbnailData == nil {
                        if let firstPhoto = entry.attachedPhotoData?.first,
                           let thumbnail = PhotoLibraryService.generateMapThumbnail(from: firstPhoto) {
                            entry.mapThumbnailData = thumbnail
                        } else {
                            return
                        }
                    }
                    entry.showOnPhotoMap = newValue
                    entry.updatedAt = Date()
                }
            ))
            .labelsHidden()
            .tint(.accentTeal)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardSurface))
        .padding(.horizontal, 16)
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

    private func formatWorkoutDuration(_ seconds: Double) -> String {
        let mins = Int(seconds / 60)
        let hrs = mins / 60
        let remainMins = mins % 60
        if hrs > 0 {
            return "\(hrs)h \(remainMins)m"
        }
        return "\(mins)m"
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

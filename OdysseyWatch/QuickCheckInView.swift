import SwiftUI
import SwiftData
import WatchKit

struct QuickCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var step: CheckInStep = .mood
    @State private var moodScore: Double = 5
    @State private var selectedFeeling: String = ""

    enum CheckInStep {
        case mood
        case feeling
        case done
    }

    var body: some View {
        switch step {
        case .mood:
            MoodCrownView(moodScore: $moodScore) {
                step = .feeling
            }
        case .feeling:
            FeelingPickerView { feeling in
                selectedFeeling = feeling
                saveEntry()
                step = .done
            }
        case .done:
            CheckInConfirmationView(
                moodScore: Int(moodScore),
                feeling: selectedFeeling
            ) {
                // Reset for next check-in
                step = .mood
                moodScore = 5
                selectedFeeling = ""
            }
        }
    }

    private func saveEntry() {
        let repo = DailyEntryRepository(context: modelContext)
        guard let entry = try? repo.fetchOrCreateToday() else { return }
        entry.feeling = Int(moodScore)
        entry.singleWordFeeling = selectedFeeling.lowercased()
        entry.feelingColorHex = moodColorHex(for: Int(moodScore))
        entry.hasUserSubmitted = true
        entry.needsSync = true
        entry.updatedAt = Date()
        try? modelContext.save()
    }

    private func moodColorHex(for value: Int) -> String {
        let color = Color.moodGradient(for: value)
        // Approximate hex from the gradient function
        let t = Double(max(1, min(10, value)) - 1) / 9.0
        let r: Double
        let g: Double
        let b: Double
        if t < 0.5 {
            let u = t / 0.5
            r = 1.0 - u * 0.04
            g = 0.32 + u * 0.33
            b = 0.31 + u * 0.05
        } else {
            let u = (t - 0.5) / 0.5
            r = 0.96 - u * 0.66
            g = 0.65 + u * 0.04
            b = 0.36 - u * 0.05
        }
        let ri = Int(r * 255)
        let gi = Int(g * 255)
        let bi = Int(b * 255)
        return String(format: "#%02x%02x%02x", ri, gi, bi)
    }
}

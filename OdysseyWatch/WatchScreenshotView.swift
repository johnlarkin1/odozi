import SwiftData
import SwiftUI

#if DEBUG
    /// Auto-cycling view for watch screenshot capture.
    /// Shows each key view for `viewDuration` seconds, then advances.
    /// The script captures screenshots at timed intervals based on this cycle.
    ///
    /// Cycle order (4 seconds each, starting at t=0):
    ///   0s  → today      (TodayGlanceView)
    ///   4s  → checkin    (MoodCrownView)
    ///   8s  → feeling    (FeelingPickerView)
    ///   12s → week       (WeekSummaryView)
    ///   16s → confirmation (CheckInConfirmationView)
    struct WatchScreenshotView: View {
        static let viewDuration: UInt64 = 4_000_000_000 // 4 seconds in nanoseconds
        static let allViews = ["today", "checkin", "feeling", "week", "confirmation"]

        @State private var currentIndex = 0

        private var currentViewName: String {
            Self.allViews[min(currentIndex, Self.allViews.count - 1)]
        }

        var body: some View {
            screenshotContent
                .id(currentIndex)
                .containerBackground(.black.gradient, for: .navigation)
                .task {
                    await cycleViews()
                }
        }

        @ViewBuilder
        private var screenshotContent: some View {
            ZStack(alignment: .bottom) {
                switch currentViewName {
                case "checkin":
                    MoodCrownView(moodScore: .constant(8)) {}
                case "feeling":
                    FeelingPickerView { _ in }
                case "week":
                    WeekSummaryView()
                case "confirmation":
                    CheckInConfirmationView(moodScore: 8, feeling: "Grateful") {}
                default:
                    TodayGlanceView()
                }

                // Debug label — remove before release screenshots
                Text("[\(currentIndex): \(currentViewName)]")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }

        private func cycleViews() async {
            for i in 1 ..< Self.allViews.count {
                try? await Task.sleep(nanoseconds: Self.viewDuration)
                currentIndex = i
            }
        }
    }

    /// Creates an in-memory container with sample data for watch screenshots.
    @MainActor
    func createWatchSeededContainer() throws -> ModelContainer {
        let container = try DataContainer.create(inMemory: true)
        let context = ModelContext(container)
        let entries = SampleData.entries
        for entry in entries {
            context.insert(entry)
        }
        try context.save()
        return container
    }
#endif

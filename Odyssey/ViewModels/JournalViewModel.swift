import SwiftData
import SwiftUI

@MainActor
@Observable
final class JournalViewModel {
    var allEntries: [DailyEntry] = []
    var selectedDate: Date = .init()

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadEntries() {
        let descriptor = FetchDescriptor<DailyEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        allEntries = (try? modelContext.fetch(descriptor)) ?? []
    }

    func entry(for date: Date) -> DailyEntry? {
        let target = Calendar.current.startOfDay(for: date)
        return allEntries.first { Calendar.current.isDate($0.date, inSameDayAs: target) }
    }
}

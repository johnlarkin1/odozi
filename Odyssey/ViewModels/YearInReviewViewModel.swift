import SwiftUI
import SwiftData

@Observable
final class YearInReviewViewModel {
    var data: YearInReviewData?
    var selectedYear: Int
    var currentCardIndex: Int = 0
    let totalCards = 10

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.selectedYear = Calendar.current.component(.year, from: Date())
    }

    func loadData() {
        let service = YearInReviewService(modelContext: modelContext)
        data = service.generate(for: selectedYear)
    }

    var progress: Double {
        Double(currentCardIndex) / Double(totalCards - 1)
    }
}

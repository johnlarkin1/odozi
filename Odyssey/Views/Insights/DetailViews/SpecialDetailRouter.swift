import SwiftUI

enum SpecialDetailRouter {
    @ViewBuilder
    static func destination(for metric: MetricDefinition, viewModel: InsightsViewModel) -> some View {
        switch metric {
        case .mood, .sleepRating, .drinks, .steps, .walkingDistance, .sleepHours, .sleepREM, .sleepDeep, .sleepCore, .sleepScore, .screenTime, .pickups:
            MetricDetailView(metric: metric, viewModel: viewModel)
        }
    }
}

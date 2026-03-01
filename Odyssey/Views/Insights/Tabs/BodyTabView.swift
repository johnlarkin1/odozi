import SwiftUI

struct BodyTabView: View {
    let viewModel: InsightsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(columns: columns, spacing: 12) {
                    NavigationLink(destination: MetricDetailView(metric: .steps, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .steps,
                            value: MetricDefinition.steps.formatValue(viewModel.averageSteps),
                            data: viewModel.sparklineData(for: .steps),
                            trend: viewModel.trend(for: .steps)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: MetricDetailView(metric: .walkingDistance, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .walkingDistance,
                            value: MetricDefinition.walkingDistance.formatValue(viewModel.averageWalkingDistanceMiles),
                            data: viewModel.sparklineData(for: .walkingDistance),
                            trend: viewModel.trend(for: .walkingDistance)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: MetricDetailView(metric: .sleepHours, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .sleepHours,
                            value: MetricDefinition.sleepHours.formatValue(viewModel.averageSleepHours),
                            data: viewModel.sparklineData(for: .sleepHours),
                            trend: viewModel.trend(for: .sleepHours)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: MetricDetailView(metric: .drinks, viewModel: viewModel)) {
                        SparklineCard(
                            metric: .drinks,
                            value: "\(viewModel.totalDrinks)",
                            data: viewModel.sparklineData(for: .drinks),
                            trend: viewModel.trend(for: .drinks)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }
}

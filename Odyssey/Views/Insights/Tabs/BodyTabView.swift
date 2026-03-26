import SwiftUI

struct BodyTabView: View {
    let viewModel: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AdaptiveGrid(minColumnWidth: 160, spacing: 12) {
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
                .adaptiveHorizontalPadding()

                // Sleep Architecture Section
                AdaptiveGrid(minColumnWidth: 160, spacing: 12) {
                    NavigationLink(destination: SleepArchitectureDetailView(viewModel: viewModel)) {
                        SleepArchitectureCard(viewModel: viewModel)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: SleepArchitectureDetailView(viewModel: viewModel)) {
                        SleepScoreCard(viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                }
                .adaptiveHorizontalPadding()

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }
}

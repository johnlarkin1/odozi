import Foundation

enum TrendCalculator {
    enum Direction {
        case up, down, flat
    }

    struct Trend {
        let direction: Direction
        let percentage: Double

        static let flat = Trend(direction: .flat, percentage: 0)
    }

    /// Computes period-over-period trend by comparing the average of the current half vs the prior half of entries.
    static func trend(for metric: MetricDefinition, entries: [DailyEntry]) -> Trend {
        let values = entries.compactMap { entry -> (Date, Double)? in
            guard let v = metric.value(from: entry) else { return nil }
            return (entry.date, v)
        }.sorted { $0.0 < $1.0 }

        guard values.count >= 2 else { return .flat }

        let mid = values.count / 2
        let priorSlice = values[0..<mid]
        let currentSlice = values[mid...]

        guard !priorSlice.isEmpty, !currentSlice.isEmpty else { return .flat }

        let priorAvg = priorSlice.map(\.1).reduce(0, +) / Double(priorSlice.count)
        let currentAvg = currentSlice.map(\.1).reduce(0, +) / Double(currentSlice.count)

        guard priorAvg != 0 else {
            if currentAvg > 0 { return Trend(direction: .up, percentage: 100) }
            return .flat
        }

        let pct = ((currentAvg - priorAvg) / abs(priorAvg)) * 100

        if abs(pct) < 1 {
            return Trend(direction: .flat, percentage: 0)
        }

        return Trend(
            direction: pct > 0 ? .up : .down,
            percentage: abs(pct)
        )
    }
}

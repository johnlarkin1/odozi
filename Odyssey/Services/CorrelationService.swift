import Foundation

enum CorrelationService {
    struct CorrelationResult {
        let metricA: MetricDefinition
        let metricB: MetricDefinition
        let coefficient: Double
        let insightText: String
    }

    /// Computes Pearson correlation between two metrics using paired non-nil data points.
    static func correlate(
        _ a: MetricDefinition,
        _ b: MetricDefinition,
        entries: [DailyEntry]
    ) -> CorrelationResult? {
        let pairs: [(Double, Double)] = entries.compactMap { entry in
            guard let va = a.value(from: entry),
                  let vb = b.value(from: entry) else { return nil }
            return (va, vb)
        }

        guard pairs.count >= 7 else { return nil }

        let n = Double(pairs.count)
        let sumA = pairs.map(\.0).reduce(0, +)
        let sumB = pairs.map(\.1).reduce(0, +)
        let sumAB = pairs.map { $0.0 * $0.1 }.reduce(0, +)
        let sumA2 = pairs.map { $0.0 * $0.0 }.reduce(0, +)
        let sumB2 = pairs.map { $0.1 * $0.1 }.reduce(0, +)

        let numerator = n * sumAB - sumA * sumB
        let denominator = sqrt((n * sumA2 - sumA * sumA) * (n * sumB2 - sumB * sumB))

        guard denominator > 0 else { return nil }

        let r = numerator / denominator

        let insight = generateInsight(a: a, b: b, r: r)
        return CorrelationResult(metricA: a, metricB: b, coefficient: r, insightText: insight)
    }

    /// Finds the strongest correlation among all metric pairs.
    static func strongestCorrelation(entries: [DailyEntry]) -> CorrelationResult? {
        let metrics = MetricDefinition.allCases
        var best: CorrelationResult?

        for i in 0..<metrics.count {
            for j in (i + 1)..<metrics.count {
                guard let result = correlate(metrics[i], metrics[j], entries: entries) else { continue }
                if let current = best {
                    if abs(result.coefficient) > abs(current.coefficient) {
                        best = result
                    }
                } else {
                    best = result
                }
            }
        }

        return best
    }

    private static func generateInsight(a: MetricDefinition, b: MetricDefinition, r: Double) -> String {
        let strength: String
        let absR = abs(r)

        if absR > 0.7 {
            strength = "strongly"
        } else if absR > 0.4 {
            strength = "moderately"
        } else {
            strength = "slightly"
        }

        let direction = r > 0 ? "positively" : "negatively"

        return "\(a.displayName) and \(b.displayName) are \(strength) \(direction) correlated (r=\(String(format: "%.2f", r)))"
    }
}

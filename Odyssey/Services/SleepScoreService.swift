import Foundation

enum SleepScoreService {
    struct SleepScore {
        let total: Int
        let durationPoints: Int
        let consistencyPoints: Int
        let interruptionPoints: Int

        var label: String {
            switch total {
            case 0...40: return "Low"
            case 41...60: return "Fair"
            case 61...80: return "Good"
            default: return "Excellent"
            }
        }
    }

    /// Computes a 0-100 sleep score approximating Apple's documented formula:
    /// - Duration: 50 pts (target 7-9 hrs)
    /// - Bedtime consistency: 30 pts (stddev of sleep onset over last 13 nights)
    /// - Interruptions: 20 pts (awake count + awake duration)
    static func computeScore(
        for entry: DailyEntry,
        recentEntries: [DailyEntry]
    ) -> SleepScore? {
        guard entry.sleepHours != nil else { return nil }

        let durationPts = durationPoints(sleepHours: entry.sleepHours ?? 0)
        let consistencyPts = consistencyPoints(
            currentOnset: entry.sleepOnset,
            recentEntries: recentEntries
        )
        let interruptionPts = interruptionPoints(
            count: entry.sleepInterruptionCount ?? 0,
            awakeMinutes: entry.sleepAwakeMinutes ?? 0
        )

        let total = min(100, durationPts + consistencyPts + interruptionPts)

        return SleepScore(
            total: total,
            durationPoints: durationPts,
            consistencyPoints: consistencyPts,
            interruptionPoints: interruptionPts
        )
    }

    // MARK: - Duration (50 pts)

    /// Target: 7-9 hours = full 50 pts.
    /// Below 7h: scale linearly (0h = 0 pts).
    /// Above 9h: slight penalty (12h+ = 35 pts).
    private static func durationPoints(sleepHours: Double) -> Int {
        if sleepHours >= 7.0 && sleepHours <= 9.0 {
            return 50
        } else if sleepHours < 7.0 {
            return Int((sleepHours / 7.0) * 50.0)
        } else {
            // Gentle penalty for oversleep: lose ~5 pts per hour over 9
            let penalty = (sleepHours - 9.0) * 5.0
            return max(25, 50 - Int(penalty))
        }
    }

    // MARK: - Bedtime Consistency (30 pts)

    /// Compare sleep onset time-of-day across recent nights.
    /// Full 30 pts if stddev < 15 min. Scales to 0 at stddev > 2 hrs.
    /// Requires at least 3 nights with onset data.
    private static func consistencyPoints(
        currentOnset: Date?,
        recentEntries: [DailyEntry]
    ) -> Int {
        // Collect onset times (time-of-day in minutes since midnight, adjusted for overnight)
        var onsetMinutes: [Double] = []

        let allEntries = recentEntries + (currentOnset != nil ? [] : [])
        for entry in allEntries {
            if let onset = entry.sleepOnset {
                onsetMinutes.append(timeOfDayMinutes(from: onset))
            }
        }
        if let onset = currentOnset {
            onsetMinutes.append(timeOfDayMinutes(from: onset))
        }

        guard onsetMinutes.count >= 3 else {
            // Not enough data — give benefit of the doubt
            return 20
        }

        let stddev = standardDeviation(onsetMinutes)

        if stddev <= 15 {
            return 30
        } else if stddev >= 120 {
            return 0
        } else {
            // Linear scale: 15 min = 30 pts, 120 min = 0 pts
            let fraction = (120.0 - stddev) / (120.0 - 15.0)
            return Int(fraction * 30.0)
        }
    }

    /// Returns minutes since midnight, adjusted so evening times (after 6 PM) become negative
    /// to handle the midnight crossover (e.g., 11 PM = -60, 1 AM = 60).
    private static func timeOfDayMinutes(from date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = Double(hour * 60 + minute)

        // Adjust for overnight: treat hours 18-23 as negative offsets from midnight
        if hour >= 18 {
            return totalMinutes - 1440.0  // e.g., 23:00 → -60
        }
        return totalMinutes  // e.g., 01:00 → 60
    }

    // MARK: - Interruptions (20 pts)

    /// Full 20 pts if 0 interruptions and 0 awake minutes.
    /// -4 pts per interruption, -1 pt per 5 min awake.
    private static func interruptionPoints(count: Int, awakeMinutes: Double) -> Int {
        let countPenalty = count * 4
        let durationPenalty = Int(awakeMinutes / 5.0)
        return max(0, 20 - countPenalty - durationPenalty)
    }

    // MARK: - Helpers

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance)
    }
}

import SwiftUI

extension DailyEntry {
    var feelingColor: Color {
        Color(PlatformColor.fromHexString(feelingColorHex))
    }

    var moodLabel: String {
        switch feeling {
        case 1 ... 2: return "Low"
        case 3 ... 4: return "Below Avg"
        case 5 ... 6: return "Neutral"
        case 7 ... 8: return "Good"
        case 9 ... 10: return "Great"
        default: return "Neutral"
        }
    }

    var moodGradientColor: Color {
        let t = Double(feeling - 1) / 9.0
        if t < 0.5 {
            let u = t / 0.5
            return Color(
                red: 1.0 - u * 0.04,
                green: 0.32 + u * 0.33,
                blue: 0.31 + u * 0.05
            )
        } else {
            let u = (t - 0.5) / 0.5
            return Color(
                red: 0.96 - u * 0.66,
                green: 0.65 + u * 0.04,
                blue: 0.36 - u * 0.05
            )
        }
    }

    var screenTimeFormatted: String {
        guard let seconds = screenTimeSeconds else { return "N/A" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var locationDisplay: String {
        if let city = city, let state = state {
            return "\(city), \(state)"
        }
        if let city = city { return city }
        if latitude != nil && longitude != nil { return "Location recorded" }
        return "No location"
    }

    var walkingDistanceFormatted: String {
        guard let meters = walkingDistanceMeters else { return "N/A" }
        let miles = meters / 1609.34
        return String(format: "%.1f mi", miles)
    }

    var hasSleepStageData: Bool {
        sleepREMHours != nil || sleepDeepHours != nil || sleepCoreHours != nil
    }

    var sleepStageBreakdown: [(label: String, hours: Double, color: Color)] {
        var stages: [(label: String, hours: Double, color: Color)] = []
        if let core = sleepCoreHours { stages.append(("Core", core, .accentAmber)) }
        if let deep = sleepDeepHours { stages.append(("Deep", deep, .accentTeal)) }
        if let rem = sleepREMHours { stages.append(("REM", rem, .cosmicPurple)) }
        if let awake = sleepAwakeMinutes { stages.append(("Awake", awake / 60.0, .coralRed)) }
        return stages
    }

    var sleepScoreLabel: String? {
        guard let score = sleepScore else { return nil }
        return SleepScoreService.label(for: score)
    }

    // MARK: - Workout

    var workouts: [WorkoutSummary] {
        guard let data = workoutDataJSON else { return [] }
        do {
            return try JSONDecoder().decode([WorkoutSummary].self, from: data)
        } catch {
            print("[DailyEntry] Failed to decode workoutDataJSON: \(error)")
            return []
        }
    }

    var didWorkout: Bool {
        workoutDataJSON != nil
    }

    var primaryWorkout: WorkoutSummary? {
        workouts.max(by: { $0.durationSeconds < $1.durationSeconds })
    }

    var primaryWorkoutLabel: String {
        guard let workout = primaryWorkout else { return "--" }
        let minutes = Int(workout.durationSeconds / 60)
        return "\(minutes)m"
    }

    var primaryWorkoutType: String {
        primaryWorkout?.activityName ?? "Workout"
    }

    var workoutIntensityLabel: String? {
        guard let score = workoutIntensityScore else { return nil }
        switch score {
        case 1...3: return "Light"
        case 4...5: return "Moderate"
        case 6...7: return "Hard"
        case 8...10: return "Intense"
        default: return nil
        }
    }

    var totalWorkoutFormatted: String {
        guard let minutes = totalWorkoutMinutes else { return "N/A" }
        let hrs = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m"
        }
        return "\(mins)m"
    }

    var hasPromptData: Bool {
        !journalEntry.isEmpty || !gratitude.isEmpty || !win.isEmpty || !tension.isEmpty || !singleWordFeeling.isEmpty
    }

    var hasPhotos: Bool {
        if let attached = attachedPhotoData, !attached.isEmpty { return true }
        if let auto = autoPhotoIdentifiers, !auto.isEmpty { return true }
        return false
    }
}

import SwiftUI

extension DailyEntry {
    var feelingColor: Color {
        Color(UIColor.fromHexString(feelingColorHex))
    }

    var moodLabel: String {
        switch feeling {
        case 1...2: return "Low"
        case 3...4: return "Below Avg"
        case 5...6: return "Neutral"
        case 7...8: return "Good"
        case 9...10: return "Great"
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

    var hasPromptData: Bool {
        !journalEntry.isEmpty || !gratitude.isEmpty || !win.isEmpty || !tension.isEmpty || !singleWordFeeling.isEmpty
    }
}

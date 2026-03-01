import SwiftUI

enum ChartMode: String, CaseIterable, Identifiable {
    case line = "Line"
    case radial = "Radial"
    case scatter = "Scatter"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .radial: return "circle.circle"
        case .scatter: return "chart.dots.scatter"
        }
    }
}

enum MetricDefinition: String, CaseIterable, Identifiable {
    // Mind
    case mood
    case sleepRating
    case drinks

    // Body
    case steps
    case walkingDistance
    case sleepHours

    // World
    case screenTime
    case pickups

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mood: return "Mood"
        case .sleepRating: return "Sleep Rating"
        case .drinks: return "Drinks"
        case .steps: return "Steps"
        case .walkingDistance: return "Walking Distance"
        case .sleepHours: return "Sleep Hours"
        case .screenTime: return "Screen Time"
        case .pickups: return "Pickups"
        }
    }

    var icon: String {
        switch self {
        case .mood: return "face.smiling"
        case .sleepRating: return "moon.stars.fill"
        case .drinks: return "cup.and.saucer.fill"
        case .steps: return "figure.walk"
        case .walkingDistance: return "map.fill"
        case .sleepHours: return "bed.double.fill"
        case .screenTime: return "iphone"
        case .pickups: return "hand.tap.fill"
        }
    }

    var color: Color {
        switch self {
        case .mood: return .accentAmber
        case .sleepRating: return .accentTeal
        case .drinks: return .coralRed
        case .steps: return .successGreen
        case .walkingDistance: return .accentTeal
        case .sleepHours: return .cosmicPurple
        case .screenTime: return .nebulaPink
        case .pickups: return .accentAmber
        }
    }

    var unit: String {
        switch self {
        case .mood: return "/10"
        case .sleepRating: return "/10"
        case .drinks: return "drinks"
        case .steps: return "steps"
        case .walkingDistance: return "mi"
        case .sleepHours: return "hrs"
        case .screenTime: return "hrs"
        case .pickups: return "pickups"
        }
    }

    var availableChartModes: [ChartMode] {
        switch self {
        case .mood, .sleepRating, .steps, .walkingDistance, .sleepHours, .screenTime, .pickups:
            return [.line, .radial, .scatter]
        case .drinks:
            return [.line, .scatter]
        }
    }

    func value(from entry: DailyEntry) -> Double? {
        switch self {
        case .mood: return Double(entry.feeling)
        case .sleepRating: return Double(entry.sleepQuality)
        case .drinks: return Double(entry.drinks)
        case .steps: return entry.stepCount.map { Double($0) }
        case .walkingDistance:
            return entry.walkingDistanceMeters.map { $0 / 1609.34 }
        case .sleepHours: return entry.sleepHours
        case .screenTime:
            return entry.screenTimeSeconds.map { $0 / 3600.0 }
        case .pickups: return entry.pickups.map { Double($0) }
        }
    }

    func formatValue(_ value: Double) -> String {
        switch self {
        case .mood, .sleepRating:
            return String(format: "%.1f", value)
        case .drinks:
            return "\(Int(value))"
        case .steps:
            return value >= 1000 ? String(format: "%.1fk", value / 1000) : "\(Int(value))"
        case .walkingDistance:
            return String(format: "%.1f", value)
        case .sleepHours:
            return String(format: "%.1f", value)
        case .screenTime:
            return String(format: "%.1f", value)
        case .pickups:
            return "\(Int(value))"
        }
    }
}

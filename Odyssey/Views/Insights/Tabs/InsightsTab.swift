import SwiftUI

enum InsightsTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case mind = "Mind"
    case body = "Body"
    case world = "World"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "sparkles"
        case .mind: return "brain.head.profile"
        case .body: return "figure.walk"
        case .world: return "globe.americas.fill"
        }
    }
}

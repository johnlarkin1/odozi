import Foundation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DeepLink")

enum DeepLinkRoute: Equatable {
    case guidedPrompt
    case today
    case journal
    case explore
    case insights
    case profile
    case weeklyReport
}

/// Parses `odyssey://` URLs and applies them to the global ``NavigationState``.
///
/// Supported routes:
/// - `odyssey://guided-prompt` — open the Today tab and start a new guided entry
/// - `odyssey://today` — switch to the Today tab
/// - `odyssey://journal` — switch to the Journal tab
/// - `odyssey://explore` — switch to the Explore tab
/// - `odyssey://insights` — switch to the Insights tab
/// - `odyssey://profile` — switch to the Profile tab
/// - `odyssey://weekly-report` — open the Weekly Reports view inside Insights
enum DeepLinkRouter {
    static let scheme = "odyssey"

    static func route(from url: URL) -> DeepLinkRoute? {
        guard url.scheme == scheme else { return nil }
        switch url.host {
        case "guided-prompt": return .guidedPrompt
        case "today": return .today
        case "journal": return .journal
        case "explore": return .explore
        case "insights": return .insights
        case "profile": return .profile
        case "weekly-report", "weekly-reports": return .weeklyReport
        default: return nil
        }
    }

    @MainActor
    static func navigate(to route: DeepLinkRoute) {
        let nav = NavigationState.shared
        logger.info("Navigating to deep link route: \(String(describing: route))")
        switch route {
        case .guidedPrompt:
            nav.selectedTab = .today
            nav.showGuidedPrompt = true
        case .today:
            nav.selectedTab = .today
        case .journal:
            nav.selectedTab = .journal
        case .explore:
            nav.selectedTab = .explore
        case .insights:
            nav.selectedTab = .insights
        case .profile:
            nav.selectedTab = .profile
        case .weeklyReport:
            nav.selectedTab = .insights
            nav.showWeeklyReports = true
        }
    }

    @MainActor
    static func handle(_ url: URL) -> Bool {
        guard let route = route(from: url) else {
            logger.warning("Ignoring unknown deep link: \(url.absoluteString)")
            return false
        }
        navigate(to: route)
        return true
    }
}

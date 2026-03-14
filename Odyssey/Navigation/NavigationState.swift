import SwiftUI

@Observable
final class NavigationState {
    static let shared = NavigationState()

    var selectedTab: Tab = .today
    var showGuidedPrompt = false

    enum Tab: Int {
        case today
        case journal
        case insights
        case profile
    }

    private init() {}
}

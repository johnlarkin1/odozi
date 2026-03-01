import SwiftUI

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Not synced"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let message):
            return message
        }
    }

    var iconName: String {
        switch self {
        case .idle:
            return "icloud.slash"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .syncing:
            return .accentAmber
        case .synced:
            return .successGreen
        case .error:
            return .coralRed
        }
    }
}

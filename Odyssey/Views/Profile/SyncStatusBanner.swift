import SwiftUI

struct SyncStatusBanner: View {
    @Environment(SyncService.self) private var syncService

    /// Called when the user taps on a session-expired error to re-authenticate.
    var onReauthenticate: (() -> Void)?

    private var isSessionExpired: Bool {
        if case let .error(message) = syncService.status {
            return message == APIError.unauthorized.localizedDescription
        }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: syncService.status.iconName)
                .foregroundStyle(syncService.status.color)

            Text(syncService.status.displayText)
                .font(.subheadline)

            Spacer()

            if let lastSync = syncService.lastSyncDate {
                Text(lastSync, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if syncService.pendingCount > 0 {
                Text("\(syncService.pendingCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentAmber, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSessionExpired {
                onReauthenticate?()
            }
        }
    }
}

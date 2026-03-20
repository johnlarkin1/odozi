import Foundation
import SwiftUI

@MainActor
@Observable
final class WatchAuthManager {
    var isSignedIn: Bool = false
    var sessionToken: String?
    var isLoading: Bool = false

    var hasAccount: Bool { isSignedIn && sessionToken != nil }

    func initialize() {
        if let token = try? KeychainService.retrieveAuthToken() {
            sessionToken = token
            isSignedIn = true
        }
    }

    func updateToken(_ token: String) {
        do {
            try KeychainService.storeAuthToken(token)
            sessionToken = token
            isSignedIn = true
        } catch {
            // Token storage failed — stay signed out
        }
    }

    func signOut() {
        isSignedIn = false
        sessionToken = nil
        try? KeychainService.deleteAuthToken()
    }
}

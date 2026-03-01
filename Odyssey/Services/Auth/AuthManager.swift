import Foundation
import SwiftUI

enum AuthStrategy {
    case apple
    case google
}

enum AuthError: Error, LocalizedError {
    case notAuthenticated
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in. Please sign in and try again."
        case .serverError(let message):
            return message
        }
    }
}

struct ClerkUser {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let imageURL: URL?

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return firstName ?? email ?? "User"
    }
}

@MainActor
@Observable
final class AuthManager {
    var isSignedIn: Bool = false
    var user: ClerkUser?
    var sessionToken: String?
    var isLoading: Bool = false
    var error: String?

    var hasAccount: Bool { isSignedIn && user != nil }

    // MARK: - Lifecycle

    func initialize() async {
        isLoading = true
        defer { isLoading = false }

        // Restore token from Keychain
        if let storedToken = try? KeychainService.retrieveAuthToken() {
            sessionToken = storedToken
        }

        // TODO: Add Clerk iOS SDK via SPM, then uncomment:
        // import ClerkSDK
        // await Clerk.shared.load()
        // if let clerkUser = Clerk.shared.user {
        //     isSignedIn = true
        //     user = mapClerkUser(clerkUser)
        //     await refreshTokenIfNeeded()
        // }
    }

    // MARK: - Authentication

    func signIn(strategy: AuthStrategy) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // TODO: Add Clerk iOS SDK via SPM, then implement:
        // switch strategy {
        // case .apple:
        //     let signIn = try await SignIn.create(strategy: .idToken(provider: .apple, idToken: appleIDToken))
        // case .google:
        //     try await SignIn.create(strategy: .oauth(.google))
        // }
        // isSignedIn = true
        // user = mapClerkUser(Clerk.shared.user)
        // if let token = await refreshTokenIfNeeded() {
        //     try KeychainService.storeAuthToken(token)
        // }
    }

    func signUp(strategy: AuthStrategy) async throws {
        // Clerk OAuth handles both sign-in and sign-up
        try await signIn(strategy: strategy)
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        // TODO: Add Clerk iOS SDK via SPM, then uncomment:
        // try? await Clerk.shared.signOut()
        isSignedIn = false
        user = nil
        sessionToken = nil
        try? KeychainService.deleteAuthToken()
    }

    @discardableResult
    func refreshTokenIfNeeded() async -> String? {
        // TODO: Add Clerk iOS SDK via SPM, then uncomment:
        // if let session = Clerk.shared.session {
        //     if let tokenResource = try? await session.getToken() {
        //         sessionToken = tokenResource.jwt
        //         try? KeychainService.storeAuthToken(tokenResource.jwt)
        //     }
        // }
        return sessionToken
    }

    func deleteAccount() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Refresh token to ensure valid auth for server call
        guard let token = await refreshTokenIfNeeded() else {
            throw AuthError.notAuthenticated
        }

        // Delete server-side data first (if this fails, user stays signed in to retry)
        do {
            try await APIClient().deleteAccount(token: token)
        } catch {
            throw AuthError.serverError("Failed to delete account: \(error.localizedDescription)")
        }

        // TODO: Add Clerk iOS SDK via SPM, then uncomment:
        // try? await Clerk.shared.signOut()

        // Clear local auth state
        isSignedIn = false
        user = nil
        sessionToken = nil
        try? KeychainService.deleteAuthToken()
    }
}

import ClerkKit
import Foundation
import SwiftUI

enum AuthStrategy {
    case apple
    case google
    case github
}

enum AuthError: Error, LocalizedError {
    case notAuthenticated
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in. Please sign in and try again."
        case let .serverError(message):
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
    nonisolated(unsafe) static var clerkConfigured = false

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

        if let storedToken = try? KeychainService.retrieveAuthToken() {
            sessionToken = storedToken
        }

        guard Self.clerkConfigured else { return }

        if let clerkUser = Clerk.shared.user {
            isSignedIn = true
            user = mapClerkUser(clerkUser)
            await refreshTokenIfNeeded()
        }
    }

    // MARK: - Authentication

    func signIn(strategy: AuthStrategy) async throws {
        guard Self.clerkConfigured else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            switch strategy {
            case .apple:
                try await Clerk.shared.auth.signInWithApple()
            case .google:
                try await Clerk.shared.auth.signInWithOAuth(provider: .google)
            case .github:
                try await Clerk.shared.auth.signInWithOAuth(provider: .github)
            }

            guard let clerkUser = Clerk.shared.user else {
                throw AuthError.serverError("Sign-in succeeded but no user returned")
            }

            isSignedIn = true
            user = mapClerkUser(clerkUser)

            if let token = await refreshTokenIfNeeded() {
                try? KeychainService.storeAuthToken(token)
            }
        } catch let clerkError {
            error = clerkError.localizedDescription
            throw clerkError
        }
    }

    func signUp(strategy: AuthStrategy) async throws {
        // Clerk OAuth handles both sign-in and sign-up
        try await signIn(strategy: strategy)
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        if Self.clerkConfigured {
            try? await Clerk.shared.auth.signOut()
        }

        isSignedIn = false
        user = nil
        sessionToken = nil
        try? KeychainService.deleteAuthToken()
    }

    @discardableResult
    func refreshTokenIfNeeded() async -> String? {
        guard Self.clerkConfigured else { return sessionToken }

        do {
            if let token = try await Clerk.shared.auth.getToken() {
                sessionToken = token
                try? KeychainService.storeAuthToken(token)
                #if os(iOS)
                    WatchConnectivityService.shared.sendToken(token)
                #endif
            }
        } catch {
            // Token refresh failed — return cached token
        }
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

        if Self.clerkConfigured {
            try? await Clerk.shared.auth.signOut()
        }

        // Clear local auth state
        isSignedIn = false
        user = nil
        sessionToken = nil
        try? KeychainService.deleteAuthToken()
    }

    // MARK: - Email Sign-Up

    func signUpWithEmail(email: String, password: String) async throws -> ClerkKit.SignUp {
        guard Self.clerkConfigured else {
            throw AuthError.serverError("Clerk not configured")
        }
        isLoading = true
        defer { isLoading = false }

        let signUp = try await Clerk.shared.auth.signUp(
            emailAddress: email,
            password: password
        )
        _ = try await signUp.sendEmailCode()
        return signUp
    }

    func completeSignIn() async throws {
        guard Self.clerkConfigured else { return }

        guard let clerkUser = Clerk.shared.user else {
            throw AuthError.serverError("Sign-up succeeded but no user returned")
        }

        isSignedIn = true
        user = mapClerkUser(clerkUser)

        if let token = await refreshTokenIfNeeded() {
            try? KeychainService.storeAuthToken(token)
        }
    }

    // MARK: - Phone 2FA

    func setupPhone2FA(phoneNumber: String) async throws -> ClerkKit.PhoneNumber {
        guard Self.clerkConfigured else {
            throw AuthError.serverError("Clerk not configured")
        }
        guard let clerkUser = Clerk.shared.user else {
            throw AuthError.notAuthenticated
        }
        isLoading = true
        defer { isLoading = false }

        let phone = try await clerkUser.createPhoneNumber(phoneNumber)
        _ = try await phone.sendCode()
        return phone
    }

    func verifyPhone2FA(phone: ClerkKit.PhoneNumber, code: String) async throws {
        guard Self.clerkConfigured else {
            throw AuthError.serverError("Clerk not configured")
        }
        isLoading = true
        defer { isLoading = false }

        _ = try await phone.verifyCode(code)
    }

    // MARK: - Helpers

    private func mapClerkUser(_ clerkUser: ClerkKit.User) -> ClerkUser {
        ClerkUser(
            id: clerkUser.id,
            email: clerkUser.emailAddresses.first?.emailAddress,
            firstName: clerkUser.firstName,
            lastName: clerkUser.lastName,
            imageURL: URL(string: clerkUser.imageUrl)
        )
    }
}

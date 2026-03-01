import Foundation
import SwiftUI

enum AuthStrategy {
    case apple
    case google
    case emailPassword(email: String, password: String)
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

        // TODO: Check cached Clerk session on launch
        // await Clerk.shared.configure(publishableKey: ClerkConfiguration.publishableKey)
        // if let session = Clerk.shared.session {
        //     isSignedIn = true
        //     user = mapClerkUser(session.user)
        //     sessionToken = session.lastActiveToken?.jwt
        // }
    }

    // MARK: - Authentication

    func signIn(strategy: AuthStrategy) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // TODO: Implement with Clerk SDK
        // switch strategy {
        // case .apple:
        //     try await Clerk.shared.signIn.create(strategy: .idToken(provider: .apple))
        // case .google:
        //     try await Clerk.shared.signIn.create(strategy: .idToken(provider: .google))
        // case .emailPassword(let email, let password):
        //     try await Clerk.shared.signIn.create(strategy: .identifier(email, password: password))
        // }
        // isSignedIn = true
        // user = mapClerkUser(Clerk.shared.session?.user)
        // sessionToken = Clerk.shared.session?.lastActiveToken?.jwt
    }

    func signUp(strategy: AuthStrategy) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // TODO: Implement with Clerk SDK
        // Similar to signIn but using Clerk.shared.signUp
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        // TODO: Implement with Clerk SDK
        // try? await Clerk.shared.signOut()
        isSignedIn = false
        user = nil
        sessionToken = nil
    }

    func refreshTokenIfNeeded() async -> String? {
        // TODO: Implement JWT refresh via Clerk SDK
        // if let session = Clerk.shared.session {
        //     sessionToken = try? await session.getToken()?.jwt
        // }
        return sessionToken
    }

    func deleteAccount() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // TODO: Implement with Clerk SDK
        // try await Clerk.shared.user?.delete()
        isSignedIn = false
        user = nil
        sessionToken = nil
    }
}

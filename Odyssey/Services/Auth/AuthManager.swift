import AuthenticationServices
import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "Auth")

enum AuthError: Error, LocalizedError {
    case notAuthenticated
    case credentialRevoked
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in. Please sign in and try again."
        case .credentialRevoked:
            return "Your Apple ID credential has been revoked. Please sign in again."
        case let .serverError(message):
            return message
        }
    }
}

struct AppleUser {
    let userIdentifier: String
    let email: String?
    let fullName: PersonNameComponents?

    var displayName: String {
        if let fullName, let givenName = fullName.givenName {
            if let familyName = fullName.familyName {
                return "\(givenName) \(familyName)"
            }
            return givenName
        }
        return email ?? "Apple User"
    }
}

@MainActor
@Observable
final class AuthManager {
    var isSignedIn: Bool = false
    var user: AppleUser?
    var isLoading: Bool = false
    var error: String?

    var hasAccount: Bool { isSignedIn && user != nil }

    private static let userEmailKey = "appleUserEmail"
    private static let userGivenNameKey = "appleUserGivenName"
    private static let userFamilyNameKey = "appleUserFamilyName"

    // MARK: - Lifecycle

    func initialize() async {
        isLoading = true
        defer { isLoading = false }

        // Migration: clear orphaned Clerk auth tokens from before SIWA migration
        if (try? KeychainService.retrieveAppleUserID()) == nil,
           (try? KeychainService.retrieveAuthToken()) != nil {
            try? KeychainService.deleteAuthToken()
            logger.info("Cleared legacy Clerk auth token")
        }

        guard let userIdentifier = try? KeychainService.retrieveAppleUserID() else {
            return
        }

        // Check if the Apple credential is still valid
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userIdentifier)
            switch state {
            case .authorized:
                isSignedIn = true
                user = loadStoredUser(userIdentifier: userIdentifier)
            case .revoked, .notFound:
                logger.info("Apple credential revoked or not found, clearing auth state")
                await signOut()
            case .transferred:
                logger.warning("Apple credential transferred to new team — forcing re-auth")
                await signOut()
            @unknown default:
                break
            }
        } catch {
            // Credential check failed (e.g., no network) — trust stored state
            logger.warning("Credential state check failed, trusting stored state: \(error.localizedDescription)")
            isSignedIn = true
            user = loadStoredUser(userIdentifier: userIdentifier)
        }
    }

    // MARK: - Sign in with Apple

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                error = "Unexpected credential type"
                return
            }

            let userIdentifier = credential.user

            // Store the stable user identifier in Keychain
            do {
                try KeychainService.storeAppleUserID(userIdentifier)
            } catch {
                self.error = "Failed to save credentials"
                return
            }

            // Store identity token if available (for server-side validation)
            if let tokenData = credential.identityToken,
               let token = String(data: tokenData, encoding: .utf8) {
                do {
                    try KeychainService.storeAuthToken(token)
                } catch {
                    logger.error("Failed to store auth token in Keychain: \(error)")
                    self.error = "Sign-in succeeded but sync token could not be saved. Sync may not work."
                }
            }

            // Apple only sends name/email on first authorization — persist them
            if let email = credential.email {
                UserDefaults.standard.set(email, forKey: Self.userEmailKey)
            }
            if let fullName = credential.fullName {
                if let givenName = fullName.givenName {
                    UserDefaults.standard.set(givenName, forKey: Self.userGivenNameKey)
                }
                if let familyName = fullName.familyName {
                    UserDefaults.standard.set(familyName, forKey: Self.userFamilyNameKey)
                }
            }

            isSignedIn = true
            user = loadStoredUser(userIdentifier: userIdentifier)

            #if os(iOS)
                if let token = try? KeychainService.retrieveAuthToken() {
                    WatchConnectivityService.shared.sendToken(token)
                }
            #endif

        case let .failure(authError):
            if (authError as? ASAuthorizationError)?.code == .canceled {
                // User cancelled — not an error
                return
            }
            error = authError.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        isSignedIn = false
        user = nil

        do { try KeychainService.deleteAppleUserID() }
        catch { logger.error("Failed to delete Apple user ID during sign-out: \(error)") }

        do { try KeychainService.deleteAuthToken() }
        catch { logger.error("Failed to delete auth token during sign-out: \(error)") }

        // TODO: Move name/email to Keychain so they survive reinstall (Apple only sends these once)
        UserDefaults.standard.removeObject(forKey: Self.userEmailKey)
        UserDefaults.standard.removeObject(forKey: Self.userGivenNameKey)
        UserDefaults.standard.removeObject(forKey: Self.userFamilyNameKey)
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // TODO: Replace with CloudKit record deletion
        guard let token = try? KeychainService.retrieveAuthToken() else {
            throw AuthError.serverError(
                "Unable to delete server data: please sign in again and retry."
            )
        }

        do {
            try await APIClient().deleteAccount(token: token)
        } catch {
            throw AuthError.serverError("Failed to delete account: \(error.localizedDescription)")
        }

        // Only clear local state after server deletion succeeds
        await signOut()
    }

    // MARK: - Token Access (for sync compatibility)

    @discardableResult
    func getStoredToken() async -> String? {
        // SIWA identity tokens expire in ~10 minutes and cannot be refreshed client-side.
        // TODO: Replace with CloudKit sync — this token may be stale.
        let token = try? KeychainService.retrieveAuthToken()
        if token != nil {
            logger.debug("Returning stored SIWA token — may be expired")
        }
        return token
    }

    // MARK: - Helpers

    private func loadStoredUser(userIdentifier: String) -> AppleUser {
        let email = UserDefaults.standard.string(forKey: Self.userEmailKey)
        let givenName = UserDefaults.standard.string(forKey: Self.userGivenNameKey)
        let familyName = UserDefaults.standard.string(forKey: Self.userFamilyNameKey)

        var nameComponents: PersonNameComponents?
        if givenName != nil || familyName != nil {
            var components = PersonNameComponents()
            components.givenName = givenName
            components.familyName = familyName
            nameComponents = components
        }

        return AppleUser(
            userIdentifier: userIdentifier,
            email: email,
            fullName: nameComponents
        )
    }
}

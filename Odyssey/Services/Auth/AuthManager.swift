import AuthenticationServices
import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "Auth")

/// Delegate that bridges ASAuthorizationController callbacks to async/await.
private class SIWARefreshDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        #else
            return ASPresentationAnchor()
        #endif
    }
}

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

        do { try KeychainService.deleteAppleUserID() } catch { logger.error("Failed to delete Apple user ID during sign-out: \(error)") }

        do { try KeychainService.deleteAuthToken() } catch { logger.error("Failed to delete auth token during sign-out: \(error)") }

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

        // CloudKit records are tied to the iCloud account — signing out
        // removes them from this device. Full CloudKit zone deletion
        // can be added as a follow-up if needed.
        await signOut()
    }

    // MARK: - Token Access (for sync compatibility)

    /// Kept alive during a token refresh to prevent the delegate from being deallocated.
    private var refreshDelegate: SIWARefreshDelegate?

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

    /// Attempts to obtain a fresh SIWA identity token by performing a new
    /// authorization request.  If the user's credential is still authorized
    /// the system will prompt only for biometric confirmation (Face ID / Touch ID).
    /// Returns `nil` when the refresh cannot be completed.
    func refreshToken() async -> String? {
        guard let userIdentifier = try? KeychainService.retrieveAppleUserID() else {
            logger.info("No stored Apple user ID — cannot refresh token")
            return nil
        }

        // Verify the credential is still authorized by Apple
        do {
            let state = try await ASAuthorizationAppleIDProvider()
                .credentialState(forUserID: userIdentifier)
            guard state == .authorized else {
                logger.info("Credential state is \(String(describing: state)) — cannot refresh")
                return nil
            }
        } catch {
            logger.error("Credential state check failed during refresh: \(error.localizedDescription)")
            return nil
        }

        // Request a fresh identity token (no scopes — name/email already stored)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])

        do {
            let authorization = try await withCheckedThrowingContinuation { continuation in
                let delegate = SIWARefreshDelegate(continuation: continuation)
                self.refreshDelegate = delegate
                controller.delegate = delegate
                controller.presentationContextProvider = delegate
                controller.performRequests()
            }

            refreshDelegate = nil

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8)
            else {
                logger.error("Refresh succeeded but no identity token in credential")
                return nil
            }

            try? KeychainService.storeAuthToken(token)
            logger.info("Successfully refreshed SIWA identity token")

            return token
        } catch {
            refreshDelegate = nil
            // ASAuthorizationError.canceled means the user dismissed — not a real error
            if (error as? ASAuthorizationError)?.code == .canceled {
                logger.info("User cancelled token refresh")
            } else {
                logger.error("Token refresh failed: \(error.localizedDescription)")
            }
            return nil
        }
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

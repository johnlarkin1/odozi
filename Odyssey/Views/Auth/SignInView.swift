import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "icloud.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentTeal)

            VStack(spacing: 12) {
                Text("Sign In")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(
                    "Odozi uses iCloud to keep your journal entries safe and synced "
                        + "across your devices. Sign in with Apple is the simplest, most "
                        + "secure way to protect your data -- no extra accounts or "
                        + "passwords needed."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task {
                    await authManager.handleSignInResult(result)
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 24)

            whyAppleOnlySection

            if authManager.isLoading {
                ProgressView()
            }

            if let error = authManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.coralRed)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle("Sign In")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .onChange(of: authManager.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    dismiss()
                }
            }
    }

    private var whyAppleOnlySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why Apple only?", systemImage: "info.circle")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentTeal)

            Text(
                "Odozi syncs through iCloud, which requires an Apple account. "
                    + "This keeps your journal data within Apple's secure ecosystem "
                    + "-- no third-party servers involved."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
    }
}

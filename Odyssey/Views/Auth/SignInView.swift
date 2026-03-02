import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentTeal)

            Text("Sign In")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                signInButton(
                    icon: "apple.logo",
                    title: "Continue with Apple",
                    action: {
                        Task {
                            do {
                                try await authManager.signIn(strategy: .apple)
                            } catch is CancellationError {
                                // User cancelled OAuth sheet
                            } catch {
                                authManager.error = error.localizedDescription
                            }
                        }
                    }
                )

                signInButton(
                    icon: "globe",
                    title: "Continue with Google",
                    action: {
                        Task {
                            do {
                                try await authManager.signIn(strategy: .google)
                            } catch is CancellationError {
                                // User cancelled OAuth sheet
                            } catch {
                                authManager.error = error.localizedDescription
                            }
                        }
                    }
                )
            }
            .padding(.horizontal, 24)

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
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                dismiss()
            }
        }
    }

    private func signInButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

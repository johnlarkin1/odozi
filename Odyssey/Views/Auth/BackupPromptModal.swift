import AuthenticationServices
import SwiftUI

struct BackupPromptModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.icloud.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentTeal)

                VStack(spacing: 12) {
                    Text("Protect Your Journal")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Phones break, get lost, or get replaced. Back up your reflections to iCloud so they're always safe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        featureBullet(icon: "icloud.fill", text: "Protected by your iCloud account")
                        featureBullet(icon: "arrow.triangle.2.circlepath", text: "Seamless iCloud backup")
                        featureBullet(icon: "iphone.and.arrow.forward", text: "Restore seamlessly to a new device")
                        featureBullet(icon: "key.slash", text: "No extra passwords to remember")
                    }
                    .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task {
                            await authManager.handleSignInResult(result)
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)

                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                whyAppleOnlySection

                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if authManager.isLoading {
                ProgressView()
            }

            if let error = authManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.coralRed)
                    .padding(.horizontal)
            }
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private var whyAppleOnlySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why Apple only?", systemImage: "info.circle")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentTeal)

            Text("Odyssey syncs through iCloud, which requires an Apple account. This keeps your journal data within Apple's secure ecosystem -- no third-party servers involved.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
    }

    private func featureBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentTeal)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

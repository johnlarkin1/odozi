import SwiftUI

struct BackupPromptModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager

    @State private var showSignUp = false
    @State private var showRecoveryKey = false
    @State private var recoveryKey = ""

    var body: some View {
        NavigationStack {
            if showRecoveryKey {
                recoveryKeyView
            } else if showSignUp {
                signUpView
            } else {
                valuePropositionView
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Value Proposition

    private var valuePropositionView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentTeal)

            VStack(spacing: 12) {
                Text("Protect Your Journal")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    featureBullet(icon: "lock.fill", text: "Encrypted on-device — only you can read your entries")
                    featureBullet(icon: "arrow.triangle.2.circlepath", text: "Auto-sync keeps your data safe")
                    featureBullet(icon: "iphone.and.arrow.forward", text: "Restore to any device")
                }
                .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showSignUp = true
                } label: {
                    Text("Create Free Account")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
                }

                Button("Maybe Later") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
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
    }

    // MARK: - Sign Up

    private var signUpView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Create Account")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                signInButton(
                    icon: "apple.logo",
                    title: "Continue with Apple",
                    action: { Task { try? await authManager.signUp(strategy: .apple) } }
                )

                signInButton(
                    icon: "globe",
                    title: "Continue with Google",
                    action: { Task { try? await authManager.signUp(strategy: .google) } }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            if authManager.isLoading {
                ProgressView()
            }

            Button("Back") {
                showSignUp = false
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task {
                    await generateRecoveryKey()
                    showRecoveryKey = true
                }
            }
        }
    }

    // MARK: - Recovery Key

    private var recoveryKeyView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentAmber)

            VStack(spacing: 8) {
                Text("Save Your Recovery Key")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("If you lose access to your account, this key is the only way to decrypt your journal entries.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text(recoveryKey)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)

            Button {
                UIPasteboard.general.string = recoveryKey
            } label: {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    .font(.subheadline)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("I've Saved My Key")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

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

    private func generateRecoveryKey() async {
        let encryptionService = EncryptionService()
        if let key = try? await encryptionService.getOrCreateKey() {
            recoveryKey = RecoveryKeyGenerator.exportAsBase64(key: key)
        }
    }
}

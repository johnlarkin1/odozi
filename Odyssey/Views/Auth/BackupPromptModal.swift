import SwiftUI

struct BackupPromptModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager

    @State private var showSignUp = false
    @State private var showRecoveryKey = false
    @State private var recoveryKey = ""
    @State private var copied = false

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

                Text("Phones break, get lost, or get replaced. A free backup keeps your reflections safe no matter what.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    featureBullet(icon: "lock.fill", text: "End-to-end encrypted — only you can read your entries")
                    featureBullet(icon: "arrow.triangle.2.circlepath", text: "Auto-sync after every entry")
                    featureBullet(icon: "iphone.and.arrow.forward", text: "Restore seamlessly to a new device")
                    featureBullet(icon: "dollarsign.circle", text: "Free forever, no subscriptions")
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
                    action: {
                        Task {
                            do {
                                try await authManager.signUp(strategy: .apple)
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
                                try await authManager.signUp(strategy: .google)
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

            Spacer()

            if authManager.isLoading {
                ProgressView()
            }

            if let error = authManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.coralRed)
                    .padding(.horizontal)
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
                UIPasteboard.general.setItems(
                    [[UIPasteboard.typeAutomatic: recoveryKey]],
                    options: [.expirationDate: Date().addingTimeInterval(60)]
                )
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    copied = false
                }
            } label: {
                Label(copied ? "Copied! (expires in 60s)" : "Copy to Clipboard", systemImage: "doc.on.doc")
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

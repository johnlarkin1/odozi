import SwiftUI

struct AccountView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showRecoveryKey = false
    @State private var recoveryKey = ""
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            Section("Sync") {
                SyncStatusBanner()

                Button("Sync Now") {
                    Task {
                        await syncService.syncPendingEntries(
                            modelContext: modelContext,
                            authManager: authManager
                        )
                    }
                }

                Button("Restore from Cloud") {
                    Task {
                        await syncService.restoreFromCloud(
                            modelContext: modelContext,
                            authManager: authManager
                        )
                    }
                }
            }

            Section("Recovery") {
                Button("Show Recovery Key") {
                    Task {
                        await generateRecoveryKey()
                        showRecoveryKey = true
                    }
                }
            }

            Section {
                Button("Sign Out") {
                    showSignOutConfirmation = true
                }
                .foregroundStyle(Color.coralRed)

                Button("Delete Account") {
                    showDeleteConfirmation = true
                }
                .foregroundStyle(Color.coralRed)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                    dismiss()
                }
            }
        } message: {
            Text("Your data will remain on this device but will no longer sync to the cloud.")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task {
                    try? await authManager.deleteAccount()
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete your account and all cloud backups. Local data on this device will be preserved.")
        }
        .sheet(isPresented: $showRecoveryKey) {
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentAmber)
                        .padding(.top, 32)

                    Text("Recovery Key")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(recoveryKey)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24)

                    Button {
                        UIPasteboard.general.string = recoveryKey
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    }

                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showRecoveryKey = false
                        }
                    }
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }

    private func generateRecoveryKey() async {
        let encryptionService = EncryptionService()
        if let key = try? await encryptionService.getOrCreateKey() {
            recoveryKey = RecoveryKeyGenerator.exportAsBase64(key: key)
        }
    }
}

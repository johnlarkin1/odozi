import SwiftUI

struct AccountView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showRecoveryKey = false
    @State private var recoveryKey = ""
    @State private var copied = false
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

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
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
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
                        do {
                            try await authManager.deleteAccount()
                            dismiss()
                        } catch {
                            deleteErrorMessage = error.localizedDescription
                            showDeleteError = true
                        }
                    }
                }
            } message: {
                Text("This will permanently delete your account and all cloud backups. Local data on this device will be preserved.")
            }
            .alert("Deletion Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage)
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
                            #if os(iOS)
                                UIPasteboard.general.setItems(
                                    [[UIPasteboard.typeAutomatic: recoveryKey]],
                                    options: [.expirationDate: Date().addingTimeInterval(60)]
                                )
                            #else
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(recoveryKey, forType: .string)
                            #endif
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied! (expires in 60s)" : "Copy to Clipboard", systemImage: "doc.on.doc")
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

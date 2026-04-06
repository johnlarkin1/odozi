import SwiftUI

struct AccountView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    var body: some View {
        List {
            Section("Account") {
                if let user = authManager.user {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentTeal)
                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let email = user.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Label("Signed in with Apple", systemImage: "apple.logo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    }
}

import SwiftUI

struct AccountCard: View {
    let onCreateAccount: () -> Void
    let onKeepLocal: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "iphone.gen3")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentTeal)

            VStack(spacing: 12) {
                Text("Your Data, Your Choice")
                    .font(.title.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)

                Text("Your journal lives on this device. Nothing leaves your phone unless you choose otherwise.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Comparison card
            VStack(spacing: 0) {
                // Keep It Local section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Keep It Local")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(Color.successGreen)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("Private by default")
                        bulletPoint("No account needed")
                        bulletPoint("Uses phone storage (entries are small)")
                    }
                }
                .padding(16)

                Divider()
                    .background(.secondary.opacity(0.3))

                // Cloud Backup section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Cloud Backup")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "cloud.fill")
                            .foregroundStyle(Color.accentTeal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("End-to-end encrypted")
                        bulletPoint("Restore across devices")
                        bulletPoint("Free account")
                    }
                }
                .padding(16)
            }
            .background(Color.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 4)

            Spacer()

            // Two equal buttons
            VStack(spacing: 12) {
                Button(action: onCreateAccount) {
                    Text("Create Free Account")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: onKeepLocal) {
                    Text("Keep It Local")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.bottom, 32)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

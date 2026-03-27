import SwiftUI

struct AccountCard: View {
    let onEnableBackup: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "icloud.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentTeal)

            VStack(spacing: 12) {
                Text("Back Up Your Journal?")
                    .font(.title.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)

                Text("Your entries are always stored on this device. Enable iCloud backup to keep them safe across devices.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "lock.shield.fill", text: "Encrypted with your Apple ID")
                featureRow(icon: "arrow.triangle.2.circlepath", text: "Sync across your devices")
                featureRow(icon: "externaldrive.fill.badge.checkmark", text: "Never lose your entries")
                featureRow(icon: "dollarsign.circle", text: "Free with iCloud")
            }
            .padding(20)
            .background(Color.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            VStack(spacing: 12) {
                Button(action: onEnableBackup) {
                    Text("Enable iCloud Backup")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: onSkip) {
                    Text("Not Now")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(.bottom, 32)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentTeal)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}

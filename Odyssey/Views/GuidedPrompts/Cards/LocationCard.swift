import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

struct LocationCard: View {
    let currentLocationDisplay: String
    let locationCapturedAt: Date?
    let isUpdating: Bool
    let errorMessage: String?
    let showOpenSettings: Bool
    let onUpdateLocation: () -> Void

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.location.iconName,
            iconColor: PromptStep.location.iconColor,
            title: PromptStep.location.title,
            subtitle: PromptStep.location.subtitle
        ) {
            VStack(spacing: 24) {
                // Location display capsule
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentTeal)
                        Text(currentLocationDisplay)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.cardSurface)
                    .clipShape(Capsule())

                    if let capturedAt = locationCapturedAt {
                        Text("Captured at \(capturedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Update button
                Button(action: onUpdateLocation) {
                    HStack(spacing: 8) {
                        if isUpdating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "location.fill")
                        }
                        Text("Update to Current Location")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentTeal.opacity(0.3))
                    .clipShape(Capsule())
                }
                .disabled(isUpdating)

                if let errorMessage {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.coralRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        if showOpenSettings {
                            Button(action: openAppSettings) {
                                Text("Open Settings")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentAmber)
                            }
                        }
                    }
                }
            }
        }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        #endif
    }
}

import SwiftUI

struct LocationPermissionCard: View {
    @AppStorage("locationCaptureMode") private var locationCaptureModeRaw = LocationCaptureMode.evening.rawValue

    private var selectedMode: LocationCaptureMode {
        LocationCaptureMode(rawValue: locationCaptureModeRaw) ?? .evening
    }

    var body: some View {
        PromptCardContainer(
            iconName: OnboardingStep.location.iconName,
            iconColor: OnboardingStep.location.iconColor,
            title: OnboardingStep.location.title,
            subtitle: OnboardingStep.location.subtitle
        ) {
            VStack(spacing: 16) {
                featureRow(icon: "map.fill", text: "Build a personal map of your journey")
                featureRow(icon: "lock.shield.fill", text: "Location captured once daily, stays on device")
                featureRow(icon: "pin.fill", text: "See where your best days happen")

                Divider()
                    .background(.white.opacity(0.2))

                VStack(spacing: 12) {
                    Text("When should we capture your location?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    ForEach(LocationCaptureMode.displayCases) { mode in
                        Button {
                            locationCaptureModeRaw = mode.rawValue
                        } label: {
                            HStack {
                                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedMode == mode ? Color.accentTeal : .white.opacity(0.4))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mode.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Text(mode.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
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

import SwiftUI

struct LocationPermissionCard: View {
    @AppStorage("locationCaptureMode") private var locationCaptureModeRaw = LocationCaptureMode.evening.rawValue
    @AppStorage("locationCaptureHour") private var locationCaptureHour = 20
    @AppStorage("locationCaptureMinute") private var locationCaptureMinute = 0

    private var selectedMode: LocationCaptureMode {
        LocationCaptureMode(rawValue: locationCaptureModeRaw) ?? .evening
    }

    private var customTimeDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: locationCaptureHour, minute: locationCaptureMinute)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                locationCaptureHour = comps.hour ?? 20
                locationCaptureMinute = comps.minute ?? 0
            }
        )
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

                    if selectedMode == .custom {
                        DatePicker("Time", selection: customTimeDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .tint(Color.accentTeal)
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

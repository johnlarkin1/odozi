import SwiftUI

struct LocationPermissionCard: View {
    @AppStorage("locationCaptureMode") private var locationCaptureModeRaw = LocationCaptureMode.fixedTime.rawValue
    @AppStorage("locationCaptureHour") private var locationCaptureHour = 20
    @AppStorage("locationCaptureMinute") private var locationCaptureMinute = 0

    private var selectedMode: LocationCaptureMode {
        LocationCaptureMode(rawValue: locationCaptureModeRaw) ?? .fixedTime
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = locationCaptureHour
                components.minute = locationCaptureMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                locationCaptureHour = components.hour ?? 20
                locationCaptureMinute = components.minute ?? 0
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

                    Picker("Capture Mode", selection: $locationCaptureModeRaw) {
                        Text("Fixed Time").tag(LocationCaptureMode.fixedTime.rawValue)
                        Text("Randomized").tag(LocationCaptureMode.randomized.rawValue)
                    }
                    .pickerStyle(.segmented)

                    if selectedMode == .fixedTime {
                        DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    } else {
                        Text("Random time between 8 AM - 10 PM each day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

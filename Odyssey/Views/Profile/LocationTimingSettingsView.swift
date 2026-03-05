import SwiftUI
import SwiftData

struct LocationTimingSettingsView: View {
    @AppStorage("locationCaptureMode") private var locationCaptureModeRaw = LocationCaptureMode.evening.rawValue
    @AppStorage("locationCaptureHour") private var locationCaptureHour = 20
    @AppStorage("locationCaptureMinute") private var locationCaptureMinute = 0

    @Environment(\.modelContext) private var modelContext

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
                updateSwiftData()
                SnapshotScheduler.scheduleSnapshotTask()
            }
        )
    }

    var body: some View {
        List {
            Section("Capture Mode") {
                ForEach(LocationCaptureMode.displayCases) { mode in
                    Button {
                        locationCaptureModeRaw = mode.rawValue
                        updateSwiftData()
                        SnapshotScheduler.scheduleSnapshotTask()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if mode == selectedMode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.cosmicPurple)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                if selectedMode == .custom {
                    DatePicker("Time", selection: customTimeDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .tint(Color.cosmicPurple)
                }
            }
            .listRowBackground(Color.cardSurface)

            if selectedMode == .randomized {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "shuffle")
                            .foregroundStyle(Color.accentTeal)
                        Text("A random time between 8 AM and 10 PM will be chosen each day")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.cardSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Location Timing")
        .cosmicBackground()
    }

    private func updateSwiftData() {
        let descriptor = FetchDescriptor<UserPreferences>()
        let existing = try? modelContext.fetch(descriptor).first
        let prefs = existing ?? UserPreferences()
        if existing == nil {
            modelContext.insert(prefs)
        }
        prefs.locationCaptureMode = locationCaptureModeRaw
        prefs.locationCaptureHour = locationCaptureHour
        prefs.locationCaptureMinute = locationCaptureMinute
        prefs.updatedAt = Date()
        try? modelContext.save()
    }
}

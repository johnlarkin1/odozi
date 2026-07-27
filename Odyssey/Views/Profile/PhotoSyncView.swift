#if os(iOS)
    import SwiftData
    import SwiftUI

    /// Sheet that lets the user pick a date range and sync photos from their
    /// library into their journal — linking each day's photos and backfilling
    /// locations from photo GPS metadata.
    struct PhotoSyncView: View {
        @Environment(\.modelContext) private var modelContext
        @Environment(\.dismiss) private var dismiss

        @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        @State private var endDate = Date()
        @State private var isSyncing = false
        @State private var summary: PhotoSyncSummary?

        private var isRangeValid: Bool { startDate <= endDate }

        var body: some View {
            NavigationStack {
                List {
                    Section {
                        DatePicker(
                            "From",
                            selection: $startDate,
                            in: ...endDate,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "To",
                            selection: $endDate,
                            in: startDate ... Date(),
                            displayedComponents: .date
                        )
                    } header: {
                        Text("Date Range")
                    } footer: {
                        Text("Photos taken on each day in this range will be linked to that day's entry. Days without a location will use the location saved in your photos.")
                    }
                    .listRowBackground(Color.cardSurface)

                    if let summary {
                        Section("Result") {
                            resultRows(for: summary)
                        }
                        .listRowBackground(Color.cardSurface)
                    }

                    Section {
                        Button {
                            Task { await runSync() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSyncing {
                                    ProgressView()
                                        .tint(.black)
                                    Text("Syncing…")
                                        .fontWeight(.semibold)
                                } else {
                                    Label("Sync Photos", systemImage: "photo.on.rectangle.angled")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.black)
                        }
                        .disabled(isSyncing || !isRangeValid)
                        .listRowBackground(isRangeValid ? Color.accentAmber : Color.gray)
                    }
                }
                .scrollContentBackground(.hidden)
                .cosmicBackground()
                .navigationTitle("Sync Photos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .environment(\.colorScheme, .dark)
        }

        @ViewBuilder
        private func resultRows(for summary: PhotoSyncSummary) -> some View {
            if summary.authorizationDenied {
                Label("Photo access is off. Enable it in Settings to sync.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(Color.accentAmber)
            } else if !summary.didAnything {
                Label("Everything's already up to date.", systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(Color.successGreen)
            } else {
                Label("\(summary.photosLinked) \(summary.photosLinked == 1 ? "photo" : "photos") linked", systemImage: "link")
                Label("\(summary.locationsSet) \(summary.locationsSet == 1 ? "location" : "locations") added", systemImage: "mappin.and.ellipse")
                Label("\(summary.daysWithPhotos) \(summary.daysWithPhotos == 1 ? "day" : "days") with photos", systemImage: "calendar")
            }
        }

        private func runSync() async {
            isSyncing = true
            summary = nil
            let service = PhotoSyncService()
            let result = await service.sync(from: startDate, to: endDate, context: modelContext)
            summary = result
            isSyncing = false
        }
    }
#endif

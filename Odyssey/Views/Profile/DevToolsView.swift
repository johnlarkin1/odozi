#if DEBUG
    import SwiftData
    import SwiftUI
    import UserNotifications

    struct DevToolsView: View {
        @Environment(\.modelContext) private var modelContext
        @Query private var allEntries: [DailyEntry]

        @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

        @State private var statusMessage: String?
        @State private var statusIsError = false
        @State private var showDigestPreview = false
        @State private var digestData: WeeklyDigestData?
        @State private var pendingNotificationCount: Int?
        @State private var showOnboardingPreview = false
        @State private var onboardingPreviewStep: OnboardingStep = .welcome

        var body: some View {
            List {
                // MARK: - Onboarding

                Section("Onboarding") {
                    Button("Replay Full Onboarding") {
                        hasCompletedOnboarding = false
                        showStatus("Onboarding reset — restarting flow")
                    }

                    Button("Preview Onboarding Step…") {
                        onboardingPreviewStep = .welcome
                        showOnboardingPreview = true
                    }
                }
                .listRowBackground(Color.cardSurface)

                // MARK: - Notifications

                Section("Notifications") {
                    Button("Send Test Reminder (5s)") {
                        runAction {
                            let content = UNMutableNotificationContent()
                            content.title = "Odyssey Reminder"
                            content.body = "Time to check in with yourself today."
                            content.sound = .default

                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                            let request = UNNotificationRequest(identifier: "dev-test-reminder", content: content, trigger: trigger)
                            try await UNUserNotificationCenter.current().add(request)
                            return "Reminder scheduled — arrives in 5s"
                        }
                    }

                    Button("Send Test Digest (5s)") {
                        runAction {
                            let digest = WeeklyDigestService.computeDigest(context: modelContext)
                            let content = UNMutableNotificationContent()
                            content.title = "Your Weekly Digest"
                            content.body = WeeklyDigestNotificationManager.formatDigestBody(digest)
                            content.sound = .default
                            content.categoryIdentifier = WeeklyDigestNotificationManager.categoryIdentifier

                            if let imageURL = renderDigestCard(digest),
                               let attachment = try? UNNotificationAttachment(identifier: "digest-card", url: imageURL, options: nil) {
                                content.attachments = [attachment]
                            }

                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                            let request = UNNotificationRequest(identifier: "dev-test-digest", content: content, trigger: trigger)
                            try await UNUserNotificationCenter.current().add(request)
                            return "Digest notification scheduled — arrives in 5s"
                        }
                    }

                    Button("Refresh Digest Content") {
                        runAction {
                            await WeeklyDigestNotificationManager.refreshContent(context: modelContext)
                            return "Digest content refreshed"
                        }
                    }

                    Button("Preview Digest Card") {
                        digestData = WeeklyDigestService.computeDigest(context: modelContext)
                        showDigestPreview = true
                    }
                }
                .listRowBackground(Color.cardSurface)

                // MARK: - Background Services

                Section("Background Services") {
                    #if os(iOS)
                        Button("Run Snapshot Capture") {
                            runAction {
                                let service = BackgroundSnapshotService()
                                let snapshot = await service.captureSnapshot()
                                applySnapshotData(snapshot, to: modelContext)
                                let city = snapshot.city ?? "Unknown"
                                let steps = snapshot.stepCount.map { "\($0) steps" } ?? "no steps"
                                return "Snapshot: \(city) · \(steps)"
                            }
                        }
                    #endif

                    Button("Capture Location Only") {
                        runAction {
                            let service = LocationCaptureService()
                            let location = try await service.captureCurrentLocation()
                            let city = location.city ?? "Unknown"
                            let state = location.state ?? ""
                            return "Location: \(city), \(state)"
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)

                // MARK: - Deep Links & Navigation

                Section("Deep Links & Navigation") {
                    Button("→ Insights Tab") {
                        NavigationState.shared.selectedTab = .insights
                        showStatus("Switched to Insights tab")
                    }

                    Button("→ Guided Prompt") {
                        NavigationState.shared.selectedTab = .today
                        NavigationState.shared.showGuidedPrompt = true
                        showStatus("Opened Guided Prompt")
                    }
                }
                .listRowBackground(Color.cardSurface)

                // MARK: - Data

                Section("Data") {
                    HStack {
                        Text("Entry Count")
                        Spacer()
                        Text("\(allEntries.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button("Seed 30 Sample Entries") {
                        runAction {
                            let entries = SampleData.entries
                            for entry in entries {
                                modelContext.insert(entry)
                            }
                            try modelContext.save()
                            return "Inserted \(entries.count) sample entries"
                        }
                    }

                    Button("Delete All Entries", role: .destructive) {
                        runAction {
                            try modelContext.delete(model: DailyEntry.self)
                            try modelContext.save()
                            return "Deleted all entries"
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)

                // MARK: - Info

                Section("Info") {
                    HStack {
                        Text("Screenshot Mode")
                        Spacer()
                        Text(ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] != nil ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Digest Enabled")
                        Spacer()
                        Text(UserDefaults.standard.bool(forKey: "weeklyDigestEnabled") ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Pending Notifications")
                        Spacer()
                        if let count = pendingNotificationCount {
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Check") {
                                Task {
                                    let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
                                    pendingNotificationCount = requests.count
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Developer Tools")
            .cosmicBackground()
            .safeAreaInset(edge: .bottom) {
                if let message = statusMessage {
                    Text(message)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(statusIsError ? Color.coralRed : Color.successGreen)
                        )
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: statusMessage)
                }
            }
            .sheet(isPresented: $showDigestPreview) {
                if let data = digestData {
                    NavigationStack {
                        ScrollView {
                            WeeklyDigestCardView(data: data)
                                .padding()
                        }
                        .cosmicBackground()
                        .navigationTitle("Digest Preview")
                        #if os(iOS)
                            .navigationBarTitleDisplayMode(.inline)
                        #endif
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showDigestPreview = false }
                                }
                            }
                    }
                    .environment(\.colorScheme, .dark)
                }
            }
            .fullScreenCover(isPresented: $showOnboardingPreview) {
                OnboardingStepPreview(initialStep: onboardingPreviewStep)
            }
        }

        // MARK: - Helpers

        private func runAction(_ action: @escaping () async throws -> String) {
            Task {
                do {
                    let message = try await action()
                    showStatus(message)
                } catch {
                    showStatus("Error: \(error.localizedDescription)", isError: true)
                }
            }
        }

        private func showStatus(_ message: String, isError: Bool = false) {
            withAnimation {
                statusMessage = message
                statusIsError = isError
            }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation {
                    statusMessage = nil
                }
            }
        }
    }

    /// Full-screen preview that lets developers step through each onboarding card
    /// with a picker to jump to any step directly.
    struct OnboardingStepPreview: View {
        let initialStep: OnboardingStep

        @Environment(\.dismiss) private var dismiss
        @Environment(AuthManager.self) private var authManager
        @State private var viewModel = OnboardingViewModel()

        var body: some View {
            ZStack(alignment: .top) {
                OnboardingFlowView(
                    viewModel: viewModel,
                    onComplete: { dismiss() }
                )
                .environment(authManager)

                // Floating step picker
                VStack(spacing: 0) {
                    HStack {
                        Button("Close") { dismiss() }
                            .font(.body.weight(.medium))

                        Spacer()

                        Text("Step \(viewModel.currentStepIndex + 1)/\(viewModel.totalSteps)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(OnboardingStep.allCases) { step in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.currentStep = step
                                    }
                                } label: {
                                    Text(step.title)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            viewModel.currentStep == step
                                                ? step.iconColor
                                                : Color.cardSurface
                                        )
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .background(.ultraThinMaterial.opacity(0.9))
            }
            .environment(\.colorScheme, .dark)
            .onAppear {
                viewModel.currentStep = initialStep
            }
        }
    }

    #Preview {
        NavigationStack {
            DevToolsView()
                .modelContainer(for: DailyEntry.self, inMemory: true)
        }
        .environment(\.colorScheme, .dark)
    }
#endif

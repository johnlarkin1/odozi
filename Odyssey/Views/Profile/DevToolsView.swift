#if DEBUG
    #if os(iOS)
        import FamilyControls
    #endif
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
        @State private var healthCheckResult: AppGroupHealthCheck.Result?
        @State private var containerFileListing: String?

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

                // MARK: - Screen Time Debug

                Section("Screen Time") {
                    let debugInfo = SharedDefaults.getScreenTimeDebugInfo()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SharedDefaults")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(debugInfo)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white)
                    }

                    if let todayEntry = allEntries.first(where: { Calendar.current.isDateInToday($0.date) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DailyEntry")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text("screenTimeSeconds: \(todayEntry.screenTimeSeconds.map { String(format: "%.0f", $0) } ?? "nil")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white)
                            Text("pickups: \(todayEntry.pickups.map { "\($0)" } ?? "nil")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white)
                            Text("formatted: \(todayEntry.screenTimeFormatted)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white)
                        }
                    } else {
                        Text("No DailyEntry for today")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Button("Run App Group Health Check") {
                        let result = AppGroupHealthCheck.run()
                        healthCheckResult = result
                        showStatus(result.summary, isError: !result.isHealthy)
                    }

                    if let result = healthCheckResult {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Check")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(result.summary)
                                .font(.caption.monospaced())
                                .foregroundStyle(result.isHealthy ? Color.successGreen : Color.coralRed)
                            ForEach(Array(result.details.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Button("Force Read SharedDefaults → DailyEntry") {
                        runAction {
                            guard let screenTime = SharedDefaults.getScreenTime() else {
                                return "SharedDefaults returned nil (no data or stale timestamp)"
                            }
                            let repository = DailyEntryRepository(context: modelContext)
                            let entry = try repository.fetchOrCreateToday()
                            entry.screenTimeSeconds = screenTime.seconds
                            entry.pickups = screenTime.pickups
                            try modelContext.save()
                            NotificationCenter.default.post(name: .screenTimeDidUpdate, object: nil)
                            return "Wrote \(screenTime.seconds)s, \(screenTime.pickups) pickups → DailyEntry"
                        }
                    }

                    #if os(iOS)
                        Button("Check FamilyControls Authorization") {
                            runAction {
                                let center = AuthorizationCenter.shared
                                let status = center.authorizationStatus
                                let statusStr: String
                                switch status {
                                case .notDetermined: statusStr = "notDetermined (never asked)"
                                case .denied: statusStr = "DENIED (user refused)"
                                case .approved: statusStr = "approved ✓"
                                @unknown default: statusStr = "unknown(\(status.rawValue))"
                                }
                                return "FamilyControls: \(statusStr)"
                            }
                        }

                        Button("Request FamilyControls Auth") {
                            runAction {
                                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                                let status = AuthorizationCenter.shared.authorizationStatus
                                return "After request: \(status)"
                            }
                        }
                    #endif

                    Button("List App Group Container Files") {
                        let suiteName = SharedDefaults.suiteName
                        guard let container = FileManager.default.containerURL(
                            forSecurityApplicationGroupIdentifier: suiteName
                        ) else {
                            containerFileListing = "containerURL nil"
                            showStatus("containerURL nil", isError: true)
                            return
                        }
                        var lines: [String] = []
                        if let enumerator = FileManager.default.enumerator(
                            at: container,
                            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        ) {
                            let df = DateFormatter()
                            df.dateFormat = "MM-dd HH:mm:ss"
                            for case let url as URL in enumerator {
                                let v = try? url.resourceValues(
                                    forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
                                )
                                if v?.isDirectory == true { continue }
                                let size = v?.fileSize ?? 0
                                let mtime = v?.contentModificationDate.map(df.string(from:)) ?? "?"
                                let rel = url.path.replacingOccurrences(of: container.path + "/", with: "")
                                lines.append("\(mtime)  \(size)B  \(rel)")
                            }
                        }
                        if lines.isEmpty {
                            containerFileListing = "EMPTY — extension has never written"
                            showStatus("Container empty", isError: true)
                        } else {
                            containerFileListing = lines.joined(separator: "\n")
                            showStatus("\(lines.count) file(s) found")
                        }
                    }

                    if let listing = containerFileListing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Container Files")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(listing)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.white)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }

                    Button("Read screentime.json (file fallback)") {
                        runAction {
                            let suiteName = SharedDefaults.suiteName
                            guard let container = FileManager.default.containerURL(
                                forSecurityApplicationGroupIdentifier: suiteName
                            ) else {
                                return "containerURL nil — main app not entitled for \(suiteName)"
                            }
                            let url = container.appendingPathComponent("screentime.json")
                            guard FileManager.default.fileExists(atPath: url.path) else {
                                return "No screentime.json at \(url.path) — extension hasn't written yet"
                            }
                            let data = try Data(contentsOf: url)
                            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                return "screentime.json present but not valid JSON"
                            }
                            let seconds = json["seconds"] as? Double ?? -1
                            let pickups = json["pickups"] as? Int ?? -1
                            let ts = json["ts"] as? Double ?? 0
                            let date = Date(timeIntervalSince1970: ts)
                            return "file: \(seconds)s, \(pickups) pickups, ts=\(date)"
                        }
                    }

                    Button("Run Snapshot + Poll Screen Time") {
                        runAction {
                            let service = BackgroundSnapshotService()
                            let snapshot = await service.captureSnapshot()
                            applySnapshotData(snapshot, to: modelContext)

                            // Poll like foregroundCatchUp does
                            let delays: [Int] = [500, 500, 750, 750, 1000, 1000, 1000, 1500, 1500, 2000]
                            for (index, delay) in delays.enumerated() {
                                try await Task.sleep(for: .milliseconds(delay))
                                if let screenTime = SharedDefaults.getScreenTime() {
                                    let repository = DailyEntryRepository(context: modelContext)
                                    let entry = try repository.fetchOrCreateToday()
                                    entry.screenTimeSeconds = screenTime.seconds
                                    entry.pickups = screenTime.pickups
                                    try modelContext.save()
                                    NotificationCenter.default.post(name: .screenTimeDidUpdate, object: nil)
                                    return "Poll \(index + 1): \(screenTime.seconds)s, \(screenTime.pickups) pickups"
                                }
                            }
                            return "Polling exhausted — SharedDefaults: \(SharedDefaults.getScreenTimeDebugInfo())"
                        }
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

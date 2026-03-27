import SwiftUI

struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @Environment(AuthManager.self) private var authManager
    @State private var showRecoverySheet = false

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 0) {
                PromptProgressBar(
                    currentStep: viewModel.currentStepIndex,
                    totalSteps: viewModel.totalSteps
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                TabView(selection: $viewModel.currentStep) {
                    ForEach(OnboardingStep.allCases) { step in
                        onboardingCard(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                OnboardingNavigationBar(
                    step: viewModel.currentStep,
                    isFirstStep: viewModel.isFirstStep,
                    onBack: { viewModel.goToPrevious() },
                    onSkip: { viewModel.skip() },
                    onNext: { viewModel.goToNext() },
                    onEnable: { handleEnable() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .cosmicBackground()
        .sheet(isPresented: $showRecoverySheet) {
            viewModel.goToNext()
        } content: {
            RecoveryKeySheet()
                .environment(authManager)
        }
    }

    @ViewBuilder
    private func onboardingCard(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeCard()
        case .location:
            LocationPermissionCard()
        case .health:
            HealthPermissionCard()
        case .screenTime:
            ScreenTimePermissionCard()
        case .notifications:
            NotificationPermissionCard()
        case .account:
            AccountCard(
                onEnableBackup: { handleEnableBackup() },
                onSkip: { viewModel.goToNext() }
            )
        case .completion:
            OnboardingCompletionCard(onGetStarted: onComplete)
        }
    }

    private func handleEnableBackup() {
        Task {
            do {
                try await authManager.signUp(strategy: .apple)
                await MainActor.run {
                    showRecoverySheet = true
                }
            } catch is CancellationError {
                // User cancelled Apple sign-in
            } catch {
                authManager.error = error.localizedDescription
            }
        }
    }

    private func handleEnable() {
        switch viewModel.currentStep {
        case .location:
            viewModel.requestLocationAccess()
        case .health:
            viewModel.requestHealthKitAccess()
        case .screenTime:
            viewModel.requestScreenTimeAccess()
        case .notifications:
            viewModel.requestNotificationAccess()
        default:
            viewModel.goToNext()
        }
    }
}

// MARK: - Recovery Key Sheet (shown after successful Apple sign-in during onboarding)

private struct RecoveryKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager

    @State private var recoveryKey = ""
    @State private var copied = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentAmber)

                VStack(spacing: 8) {
                    Text("Save Your Recovery Key")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("If you lose access to your account, this key is the only way to decrypt your journal entries.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if isLoading {
                    ProgressView()
                } else {
                    Text(recoveryKey)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24)

                    Button {
                        #if os(iOS)
                            UIPasteboard.general.setItems(
                                [[UIPasteboard.typeAutomatic: recoveryKey]],
                                options: [.expirationDate: Date().addingTimeInterval(60)]
                            )
                        #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(recoveryKey, forType: .string)
                        #endif
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied! (expires in 60s)" : "Copy to Clipboard", systemImage: "doc.on.doc")
                            .font(.subheadline)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("I've Saved My Key")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .task {
            await generateRecoveryKey()
            isLoading = false
        }
    }

    private func generateRecoveryKey() async {
        let encryptionService = EncryptionService()
        if let key = try? await encryptionService.getOrCreateKey() {
            recoveryKey = RecoveryKeyGenerator.exportAsBase64(key: key)
        }
    }
}

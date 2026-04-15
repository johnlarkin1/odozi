import SwiftUI

struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @Environment(AuthManager.self) private var authManager
    @State private var showBackupSheet = false

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
                    onNext: { viewModel.goToNext() },
                    onEnable: { handleEnable() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .cosmicBackground()
        .sheet(isPresented: $showBackupSheet) {
            if authManager.isSignedIn {
                viewModel.goToNext()
            }
        } content: {
            BackupPromptModal()
                .environment(authManager)
        }
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn && viewModel.currentStep == .account {
                viewModel.goToNext()
            }
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
                onEnableBackup: { showBackupSheet = true },
                onSkip: { viewModel.goToNext() }
            )
        case .completion:
            OnboardingCompletionCard(onGetStarted: onComplete)
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

import SwiftUI

struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
                onCreateAccount: { handleCreateAccount() },
                onKeepLocal: { viewModel.goToNext() }
            )
        case .completion:
            OnboardingCompletionCard(onGetStarted: onComplete)
        }
    }

    private func handleCreateAccount() {
        viewModel.beginAccountCreation()
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

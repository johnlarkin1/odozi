import CoreLocation
import SwiftUI
#if os(iOS)
    import DeviceActivity
    import FamilyControls
#endif
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "Onboarding")

@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    /// Set after Screen Time permission is granted so the flow can ask which apps and
    /// categories to measure. Without a selection nothing is monitored.
    var showScreenTimeAppPicker = false

    var currentStepIndex: Int {
        OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0
    }

    var totalSteps: Int {
        OnboardingStep.allCases.count
    }

    var isFirstStep: Bool {
        currentStep == .welcome
    }

    var isLastStep: Bool {
        currentStep == .completion
    }

    func goToNext() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < OnboardingStep.allCases.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep.allCases[currentIndex + 1]
        }
    }

    func goToPrevious() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep.allCases[currentIndex - 1]
        }
    }

    // MARK: - Notifications

    func requestNotificationAccess() {
        Task {
            let granted = await NotificationService.requestAuthorization()
            if granted {
                NotificationService.scheduleReminder(timeOfDay: .evening)
            }
            await MainActor.run { goToNext() }
        }
    }

    // MARK: - Account

    func beginAccountCreation() {
        goToNext()
    }

    // MARK: - Permission Requests

    @MainActor
    func requestLocationAccess() {
        Task {
            // Wait for the user's answer (a throwaway manager here used to deallocate before the
            // grant could be observed), then — the Apple-recommended two-step flow — ask for the
            // Always upgrade that background capture needs. Monitoring starts once it's granted.
            let status = await LocationAuthorization.shared.requestWhenInUse()
            #if os(iOS)
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    LocationMonitoringService.shared.register()
                }
            #else
                _ = status
            #endif
            // The answer can arrive after the user has already moved on (Next tapped during the
            // timeout), and repeated taps resume several waiters with the same answer — only
            // advance if we're still on this step, or onboarding skips Health.
            guard currentStep == .location else { return }
            goToNext()
        }
    }

    func requestHealthKitAccess() {
        #if os(iOS)
            guard HealthKitService.isAvailable else {
                goToNext()
                return
            }
            Task {
                let service = HealthKitService()
                try? await service.requestAuthorization()
                await MainActor.run { goToNext() }
            }
        #else
            goToNext()
        #endif
    }

    func requestScreenTimeAccess() {
        #if os(iOS) && !targetEnvironment(simulator)
            let authorizationCenter = AuthorizationCenter.shared
            Task {
                do {
                    try await authorizationCenter.requestAuthorization(for: .individual)
                    logger.info("Screen Time API access granted.")
                    setupDeviceActivityMonitoring()
                    if ScreenTimeMonitoringManager.setupState == .noSelection {
                        // goToNext() happens when the app picker sheet is dismissed.
                        await MainActor.run { showScreenTimeAppPicker = true }
                        return
                    }
                } catch {
                    logger.error("Screen Time API access error: \(error)")
                }
                await MainActor.run { goToNext() }
            }
        #else
            goToNext()
        #endif
    }

    #if os(iOS)
        private func setupDeviceActivityMonitoring() {
            ScreenTimeMonitoringManager.register()
        }
    #endif
}

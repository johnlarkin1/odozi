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

    private let locationManager = CLLocationManager()

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

    func skip() {
        goToNext()
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
        // TODO: Present sign-up sheet via AuthManager when Clerk SDK is integrated
        goToNext()
    }

    // MARK: - Permission Requests

    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
        goToNext()
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
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
                repeats: true
            )

            let center = DeviceActivityCenter()
            do {
                try center.startMonitoring(
                    DeviceActivityName("Odyssey"),
                    during: schedule
                )
            } catch {
                logger.error("Device activity monitoring setup failed: \(error)")
            }
        }
    #endif
}

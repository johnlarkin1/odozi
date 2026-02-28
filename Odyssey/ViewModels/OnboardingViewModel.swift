import SwiftUI
import CoreLocation
import FamilyControls
import DeviceActivity
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

    // MARK: - Permission Requests

    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
        goToNext()
    }

    func requestHealthKitAccess() {
        guard HealthKitService.isAvailable else {
            goToNext()
            return
        }
        Task {
            let service = HealthKitService()
            try? await service.requestAuthorization()
            await MainActor.run { goToNext() }
        }
    }

    func requestScreenTimeAccess() {
        #if !targetEnvironment(simulator)
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
}

import CoreLocation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "LocationCapture")

/// Cached fixes older than this are rejected. A stale-but-recent coordinate is far more useful
/// than nothing for a once-daily snapshot, but a week-old fix would silently mislabel whichever
/// journal day it lands on.
private let maxCachedFixAge: TimeInterval = 24 * 60 * 60

/// The policy for what to do when a live location request fails or times out.
///
/// Deliberately a standalone, non-isolated type rather than a method on `SingleLocationRequest`:
/// it keeps the pure decision testable without exposing the delegate machinery or forcing tests
/// onto the main actor.
enum LocationFallback {
    static func result(
        cached: CLLocation?,
        error: Error,
        now: Date = Date()
    ) -> Result<CLLocation, Error> {
        guard let cached,
              abs(cached.timestamp.timeIntervalSince(now)) < maxCachedFixAge
        else {
            return .failure(error)
        }
        return .success(cached)
    }
}

enum LocationCaptureError: Error {
    case permissionDenied
    case permissionNotDetermined
    case locationUnavailable(Error)
}

struct LocationSnapshot: Sendable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let state: String?
    let country: String?
}

@MainActor
final class LocationCaptureService {
    func captureCurrentLocation() async throws -> LocationSnapshot {
        // Read through the long-lived manager LocationMonitoringService already owns rather
        // than allocating a throwaway CLLocationManager just to read a status.
        switch LocationMonitoringService.shared.authorizationStatus {
        case .denied, .restricted:
            throw LocationCaptureError.permissionDenied
        case .notDetermined:
            throw LocationCaptureError.permissionNotDetermined
        default:
            break
        }

        let location: CLLocation
        do {
            location = try await SingleLocationRequest().run()
        } catch let error as LocationCaptureError {
            throw error
        } catch {
            throw LocationCaptureError.locationUnavailable(error)
        }

        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: placemark?.locality,
            state: placemark?.administrativeArea,
            country: placemark?.isoCountryCode
        )
    }
}

@MainActor
private final class SingleLocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    // Pin self alive across the async boundary — CLLocationManager stores its
    // delegate weakly, so without this the whole request chain deallocates as
    // soon as run() returns its continuation and the callback never fires.
    private var selfRef: SingleLocationRequest?
    private var timeoutTask: Task<Void, Never>?

    /// - Parameter timeout: iOS gives a `BGAppRefreshTask` roughly 30 seconds before its
    ///   expiration handler fires and cancels everything in flight. 10s here leaves headroom for
    ///   the concurrent HealthKit fetch and the reverse geocode that follows. Raising it risks
    ///   blowing the whole snapshot, not just the location half.
    func run(timeout: Duration = .seconds(10)) async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.selfRef = self
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()

            // requestLocation() can silently never call back — common when a suspended app is
            // woken in the background. Without this the continuation hangs until the BGTask
            // expires, taking the health capture down with it (they're awaited together via
            // `async let`). Time out and fall back to the last cached fix instead.
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self, self.continuation != nil else { return }
                self.finishWithFallback(error: CLError(.locationUnknown))
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            guard let loc = last else {
                self.finishWithFallback(error: CLError(.locationUnknown))
                return
            }
            self.finish(.success(loc))
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finishWithFallback(error: error)
        }
    }

    private func finishWithFallback(error: Error) {
        let cached = manager.location
        let result = LocationFallback.result(cached: cached, error: error)
        switch result {
        case .success:
            // Log the age and accuracy so an unexpectedly-placed entry is diagnosable.
            let age = cached.map { Int(abs($0.timestamp.timeIntervalSinceNow)) } ?? 0
            let accuracy = cached?.horizontalAccuracy ?? -1
            logger.info("Live fix unavailable; using cached fix (age \(age)s, accuracy \(accuracy, format: .fixed(precision: 0))m)")
        case .failure:
            logger.error("Live fix failed with no usable cached fix: \(error.localizedDescription, privacy: .public)")
        }
        finish(result)
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        // The timeout and the delegate callback race; whichever loses must not resume twice.
        guard let continuation else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
        self.continuation = nil
        selfRef = nil
    }
}

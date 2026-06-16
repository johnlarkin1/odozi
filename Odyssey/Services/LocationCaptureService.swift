import CoreLocation
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "LocationCapture")

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
        switch CLLocationManager().authorizationStatus {
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
final class SingleLocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    // Pin self alive across the async boundary — CLLocationManager stores its
    // delegate weakly, so without this the whole request chain deallocates as
    // soon as run() returns its continuation and the callback never fires.
    private var selfRef: SingleLocationRequest?
    private var timeoutTask: Task<Void, Never>?

    func run(timeout: Duration = .seconds(10)) async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.selfRef = self
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()

            // requestLocation() can silently never call back (e.g. background BGTask
            // under When-In-Use auth). Time out and fall back to the last cached fix.
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
        let result = SingleLocationRequest.fallbackResult(cached: manager.location, error: error)
        switch result {
        case .success:
            logger.info("Live location fix timed out or failed; using cached fix")
        case .failure:
            logger.error("Live location fix failed with no cached fix available: \(error.localizedDescription, privacy: .public)")
        }
        finish(result)
    }

    /// A live request can fail or time out (common in the background). Prefer the last
    /// cached fix over giving up — a stale-but-real coordinate is far more useful for a
    /// once-daily journal snapshot than no location at all. Pure so it can be unit-tested.
    static func fallbackResult(cached: CLLocation?, error: Error) -> Result<CLLocation, Error> {
        if let cached {
            return .success(cached)
        }
        return .failure(error)
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
        self.continuation = nil
        selfRef = nil
    }
}

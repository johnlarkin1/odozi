import CoreLocation

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
private final class SingleLocationRequest: NSObject, CLLocationManagerDelegate {
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

            // requestLocation() can silently never call back — most notably from a
            // background BGTask under When-In-Use authorization, where a live fix is
            // not granted. Without this guard the continuation hangs until the BGTask
            // expiration handler cancels everything, so the whole snapshot (location
            // *and* health) is lost. Time out and fall back to the last cached fix,
            // which stays readable in the background under When-In-Use.
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

    // A live request can fail or time out (common in the background). Prefer the
    // last cached fix over giving up — a stale-but-real coordinate is far more
    // useful for a once-daily journal snapshot than no location at all.
    private func finishWithFallback(error: Error) {
        if let cached = manager.location {
            finish(.success(cached))
        } else {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard continuation != nil else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        continuation?.resume(with: result)
        continuation = nil
        selfRef = nil
    }
}

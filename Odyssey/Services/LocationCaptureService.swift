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

    func run() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.selfRef = self
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            guard let loc = last else {
                self.finish(.failure(CLError(.locationUnknown)))
                return
            }
            self.finish(.success(loc))
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finish(.failure(error))
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        manager.stopUpdatingLocation()
        continuation?.resume(with: result)
        continuation = nil
        selfRef = nil
    }
}

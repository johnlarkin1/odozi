import CoreLocation

actor LocationCaptureService {
    func captureCurrentLocation() async throws -> LocationSnapshot {
        let location = try await requestSingleLocation()
        let placemark = try? await reverseGeocode(location)

        return LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: placemark?.locality,
            state: placemark?.administrativeArea,
            country: placemark?.isoCountryCode
        )
    }

    private func requestSingleLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = SingleLocationDelegate(continuation: continuation)
            let manager = CLLocationManager()
            manager.delegate = delegate
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            // Hold reference to delegate through objc association
            objc_setAssociatedObject(manager, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            manager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> CLPlacemark? {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first
    }
}

struct LocationSnapshot {
    let latitude: Double
    let longitude: Double
    let city: String?
    let state: String?
    let country: String?
}

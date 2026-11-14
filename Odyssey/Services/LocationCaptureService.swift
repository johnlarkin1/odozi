import CoreLocation
import Observation
import os
#if canImport(UIKit)
    import UIKit
#endif

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "LocationCapture")

/// A fix older than this isn't attributed to "now". A recent cached coordinate is far more useful
/// than nothing for a once-daily snapshot, but an old one would silently mislabel the journal day.
private let maxFixAge: TimeInterval = 4 * 60 * 60

/// Decides whether an already-known fix (a cached one after a failed live request, or one iOS
/// delivered on a significant-location-change wake) can stand in for "where the user is today".
///
/// Deliberately a standalone, non-isolated type so the pure decision is testable without the
/// delegate machinery or the main actor.
enum LocationFallback {
    static func result(
        cached: CLLocation?,
        error: Error,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Result<CLLocation, Error> {
        guard let cached, isUsable(cached, now: now, calendar: calendar) else {
            return .failure(error)
        }
        return .success(cached)
    }

    /// A fix is usable for `now`'s journal day only if it's valid, recent, and was taken on the
    /// same calendar day. Without the same-day rule a fix from 11 PM would land on tomorrow's entry
    /// and — because a day's first location sticks — stay there.
    static func isUsable(_ location: CLLocation, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let age = now.timeIntervalSince(location.timestamp)
        return location.horizontalAccuracy >= 0
            && age < maxFixAge
            && age > -60 // tolerate small clock skew, reject fixes from the future
            && calendar.isDate(location.timestamp, inSameDayAs: now)
    }
}

enum LocationCaptureError: Error {
    case permissionDenied
    case permissionNotDetermined
    /// Only When-In-Use is granted and the app isn't in the foreground, so iOS won't hand out a
    /// fix. Background capture needs "Always".
    case needsAlwaysAuthorization
    case locationUnavailable(Error)
}

struct LocationSnapshot: Sendable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let state: String?
    let country: String?
    /// When the underlying fix was taken — not when it was captured or applied.
    let timestamp: Date
}

// MARK: - Authorization

/// The single, observable source of truth for location authorization, shared by every caller
/// (onboarding, guided prompts, Today, Profile). Owns one long-lived `CLLocationManager` so a
/// permission request survives until the user answers — a throwaway manager deallocates
/// immediately and its prompt (and answer) is lost.
///
/// Background *monitoring* lives in the iOS-only `LocationMonitoringService`; this type is shared
/// with the macOS target.
@MainActor
@Observable
final class LocationAuthorization: NSObject {
    static let shared = LocationAuthorization()

    private(set) var status: CLAuthorizationStatus
    private(set) var accuracy: CLAccuracyAuthorization

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private var waiters: [CheckedContinuation<CLAuthorizationStatus, Never>] = []

    override private init() {
        let manager = CLLocationManager()
        self.manager = manager
        status = manager.authorizationStatus
        accuracy = manager.accuracyAuthorization
        super.init()
        manager.delegate = self
    }

    var isAuthorized: Bool {
        status == .authorizedAlways || status == .authorizedWhenInUse
    }

    /// The most recent fix the system has cached for this app, if any.
    var lastKnownLocation: CLLocation? {
        manager.location
    }

    /// Shows the When-In-Use prompt if the user has never been asked, then waits for their answer.
    /// Returns the resulting status immediately when it's already determined, and gives up after
    /// `timeout` — iOS may not show the prompt at all (e.g. the macOS app isn't entitled for
    /// location), and callers mustn't spin forever waiting for an answer that never comes.
    func requestWhenInUse(timeout: Duration = .seconds(60)) async -> CLAuthorizationStatus {
        refresh()
        guard status == .notDetermined else { return status }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            guard waiters.count == 1 else { return }
            manager.requestWhenInUseAuthorization()
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                self.resumeWaiters()
            }
        }
    }

    private func refresh() {
        status = manager.authorizationStatus
        accuracy = manager.accuracyAuthorization
    }

    /// Resumes everyone waiting on a permission answer. Waiters are removed before being resumed,
    /// so the delegate and the timeout can't resume the same continuation twice.
    private func resumeWaiters() {
        refresh()
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume(returning: status)
        }
    }
}

extension LocationAuthorization: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        Task { @MainActor in
            self.refresh()
            // The delegate also fires once on creation with the current (possibly still
            // undetermined) status — only resume waiters once the user has actually answered.
            guard self.status != .notDetermined else { return }
            self.resumeWaiters()
        }
    }
}

// MARK: - Reverse geocoding

/// A human-readable place for a coordinate.
struct Place: Sendable {
    let city: String?
    let state: String?
    let country: String?
}

@MainActor
enum PlaceResolver {
    /// Reverse-geocodes `location`, giving up after `timeout`. Geocoding needs the network and is
    /// rate-limited, so it must never be allowed to hold a background capture hostage: on timeout,
    /// cancellation or failure this returns nil and the caller keeps the bare coordinates.
    static func place(for location: CLLocation, timeout: Duration = .seconds(5)) async -> Place? {
        await GeocodeRequest().run(location, timeout: timeout)
    }
}

/// One reverse-geocode round-trip with a timeout and cancellation. Same shape as
/// `SingleLocationRequest`: main-actor state, a single continuation, first finisher wins.
@MainActor
private final class GeocodeRequest {
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<Place?, Never>?
    private var timeoutTask: Task<Void, Never>?

    func run(_ location: CLLocation, timeout: Duration) async -> Place? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    let place = placemarks?.first.map {
                        Place(city: $0.locality, state: $0.administrativeArea, country: $0.isoCountryCode)
                    }
                    if let error {
                        logger.info("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
                    }
                    Task { @MainActor in self.finish(place) }
                }
                timeoutTask = Task { @MainActor in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    logger.info("Reverse geocode timed out")
                    self.cancel()
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    private func cancel() {
        geocoder.cancelGeocode()
        finish(nil)
    }

    private func finish(_ place: Place?) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: place)
    }
}

// MARK: - Capture

@MainActor
final class LocationCaptureService {
    /// Gets a live fix (falling back to a recent same-day cached one) and reverse-geocodes it.
    func captureCurrentLocation() async throws -> LocationSnapshot {
        switch LocationAuthorization.shared.status {
        case .denied, .restricted:
            throw LocationCaptureError.permissionDenied
        case .notDetermined:
            throw LocationCaptureError.permissionNotDetermined
        default:
            break
        }

        let location = try await currentLocation()
        return await snapshot(for: location)
    }

    /// Reverse-geocodes a fix the caller already has (e.g. one delivered on a significant-location-
    /// change wake) without asking CoreLocation for another one.
    func snapshot(for location: CLLocation) async -> LocationSnapshot {
        let place = await PlaceResolver.place(for: location)
        return LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: place?.city,
            state: place?.state,
            country: place?.country,
            timestamp: location.timestamp
        )
    }

    private func currentLocation() async throws -> CLLocation {
        #if canImport(UIKit) && !os(watchOS)
            // When-In-Use grants nothing in the background: iOS refuses (or silently never answers)
            // a request made there. Don't burn the BGTask's time budget waiting for the timeout —
            // use a same-day cached fix if there is one, otherwise report that Always is needed.
            // `.background` only: `.inactive` is still foreground (cold launch before activation,
            // a system alert or the permission prompt on screen) and iOS serves it a live fix.
            if LocationAuthorization.shared.status == .authorizedWhenInUse,
               UIApplication.shared.applicationState == .background {
                return try LocationFallback.result(
                    cached: LocationAuthorization.shared.lastKnownLocation,
                    error: LocationCaptureError.needsAlwaysAuthorization
                ).get()
            }
        #endif

        do {
            return try await SingleLocationRequest().run()
        } catch let error as LocationCaptureError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LocationCaptureError.locationUnavailable(error)
        }
    }
}

/// One `requestLocation()` round-trip as an async call, with a timeout, cancellation support, and
/// a same-day cached-fix fallback.
@MainActor
private final class SingleLocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?

    /// - Parameter timeout: iOS gives a `BGAppRefreshTask` roughly 30 seconds, and a
    ///   significant-location-change wake about 10. 10s here leaves headroom for the HealthKit
    ///   fetch and the reverse geocode that follow.
    func run(timeout: Duration = .seconds(10)) async throws -> CLLocation {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                manager.requestLocation()

                // requestLocation() can silently never call back — common when a suspended app is
                // woken in the background. Time out and fall back to a cached fix instead.
                // Captures `self` strongly on purpose: CLLocationManager holds its delegate weakly,
                // so this keeps the request alive until it finishes (finish() cancels the task).
                timeoutTask = Task { @MainActor in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    self.finishWithFallback(error: CLError(.locationUnknown))
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.finish(.failure(CancellationError()))
            }
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            guard let last else {
                self.finishWithFallback(error: CLError(.locationUnknown))
                return
            }
            self.finish(.success(last))
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finishWithFallback(error: error)
        }
    }

    private func finishWithFallback(error: Error) {
        let cached = manager.location ?? LocationAuthorization.shared.lastKnownLocation
        let result = LocationFallback.result(cached: cached, error: error)
        switch result {
        case let .success(location):
            // Log the age and accuracy so an unexpectedly-placed entry is diagnosable.
            let age = Int(abs(location.timestamp.timeIntervalSinceNow))
            logger.info("Live fix unavailable; using cached fix (age \(age)s, accuracy \(location.horizontalAccuracy, format: .fixed(precision: 0))m)")
        case .failure:
            logger.error("Live fix failed with no usable cached fix: \(error.localizedDescription, privacy: .public)")
        }
        finish(result)
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        // The timeout, cancellation and the delegate callback race; only the first may resume.
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }
}

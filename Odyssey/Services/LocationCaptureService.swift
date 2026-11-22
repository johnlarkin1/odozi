import CoreLocation
import MapKit
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
    /// Gives up on the current prompt. Cancelled once the waiters are resumed, so a stale timer
    /// from an earlier request can never resume a later one while its prompt is still up.
    @ObservationIgnored private var waitTimeout: Task<Void, Never>?

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

    /// The live authorization status. Prefer this over `status` when gating work: `status` is
    /// updated through an async hop from the delegate, so right after a change in Settings (or on a
    /// background wake) it can briefly lag the manager.
    var currentStatus: CLAuthorizationStatus {
        refresh()
        return status
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
        #if os(macOS)
            // The Mac app has no location entitlement, so no prompt would ever appear and callers
            // would show a spinner for the whole timeout. Report the undetermined status now.
            return status
        #else
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
                guard waiters.count == 1 else { return }
                manager.requestWhenInUseAuthorization()
                waitTimeout = Task { @MainActor in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    self.resumeWaiters()
                }
            }
        #endif
    }

    private func refresh() {
        status = manager.authorizationStatus
        accuracy = manager.accuracyAuthorization
    }

    /// Resumes everyone waiting on a permission answer. Waiters are removed before being resumed,
    /// so the delegate and the timeout can't resume the same continuation twice.
    private func resumeWaiters() {
        refresh()
        waitTimeout?.cancel()
        waitTimeout = nil
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
struct Place: Sendable, Equatable {
    let city: String?
    /// State / province, when the region has one (e.g. "NY").
    let state: String?
    /// ISO 3166-1 region code (e.g. "US").
    let country: String?

    /// MapKit has no `administrativeArea`; its short city-with-context string is "City, State"
    /// where a state applies. Take the part after the city — unless that part is the country:
    /// the short style only omits "United States", so outside the US it reads e.g. "Paris, France".
    ///
    /// - Parameter regionNames: names the country might appear under (MapKit's `regionName`, the
    ///   localized name for the region code). A part matching one of them isn't a state.
    static func state(fromShortCityContext context: String?, city: String?, regionNames: [String] = []) -> String? {
        guard let context, let city, !city.isEmpty else { return nil }
        let prefix = city + ", "
        guard context.hasPrefix(prefix) else { return nil }
        guard let state = context.dropFirst(prefix.count)
            .split(separator: ",", maxSplits: 1).first
            .map({ $0.trimmingCharacters(in: .whitespaces) }),
            !state.isEmpty
        else { return nil }
        let isCountry = regionNames.contains { $0.caseInsensitiveCompare(state) == .orderedSame }
        return isCountry ? nil : state
    }
}

@available(macOS 26.0, *)
extension Place {
    init(mapItem: MKMapItem) {
        let address = mapItem.addressRepresentations
        let city = address?.cityName
        let regionCode = address?.region?.identifier
        let regionNames = [
            address?.regionName,
            regionCode.flatMap { Locale.current.localizedString(forRegionCode: $0) }
        ].compactMap { $0 }
        self.init(
            city: city,
            state: Self.state(
                fromShortCityContext: address?.cityWithContext(.short),
                city: city,
                regionNames: regionNames
            ),
            country: regionCode
        )
    }
}

@MainActor
enum PlaceResolver {
    /// Reverse-geocodes `location` with MapKit, giving up after `timeout`. Geocoding needs the
    /// network and is rate-limited, so it must never be allowed to hold a background capture
    /// hostage: on timeout, cancellation or failure this returns nil and the caller keeps the bare
    /// coordinates (they're named on a later capture).
    static func place(for location: CLLocation, timeout: Duration = .seconds(5)) async -> Place? {
        #if os(macOS)
            // The Mac target still supports macOS 14, but it never captures location (it has no
            // location usage description), so there's nothing to name before macOS 26.
            guard #available(macOS 26.0, *) else { return nil }
        #endif
        return await GeocodeRequest().run(location, timeout: timeout)
    }
}

/// One `MKReverseGeocodingRequest` round-trip with a timeout and cancellation. Same shape as
/// `SingleLocationRequest`: main-actor state, a single continuation, first finisher wins.
@available(macOS 26.0, *)
@MainActor
private final class GeocodeRequest {
    private var request: MKReverseGeocodingRequest?
    private var continuation: CheckedContinuation<Place?, Never>?
    private var timeoutTask: Task<Void, Never>?

    func run(_ location: CLLocation, timeout: Duration) async -> Place? {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            logger.info("Reverse geocode: invalid location")
            return nil
        }
        self.request = request

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                // MapKit calls this on the main actor.
                request.getMapItems { mapItems, error in
                    if let error {
                        logger.info("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
                    }
                    self.finish(mapItems?.first.map(Place.init(mapItem:)))
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
        request?.cancel()
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
        switch LocationAuthorization.shared.currentStatus {
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
            if LocationAuthorization.shared.currentStatus == .authorizedWhenInUse,
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

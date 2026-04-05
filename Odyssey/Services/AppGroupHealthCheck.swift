#if DEBUG
    import Foundation
    import os

    private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "AppGroupHealth")

    /// DEBUG-only diagnostic that verifies the App Group container is actually
    /// entitled for this process. Compiled out of Release builds.
    ///
    /// The usual silent-failure mode is: `Odyssey.entitlements` lists the App Group,
    /// but Apple's App ID doesn't have App Groups enabled, so the signed provisioning
    /// profile strips it. `UserDefaults(suiteName:)` still returns a non-nil object
    /// (writes go to `/dev/null`), and cfprefsd logs:
    ///   "Container: (null) ... detaching from cfprefsd"
    /// This check catches that by going through `containerURL` (authoritative) and
    /// performing a write→read round-trip on UserDefaults.
    enum AppGroupHealthCheck {
        struct Result {
            let suiteName: String
            let containerURL: URL?
            let userDefaultsNonNil: Bool
            let roundTripSucceeded: Bool
            let fileWriteSucceeded: Bool
            let fileReadSucceeded: Bool
            let details: [String]

            var isHealthy: Bool {
                containerURL != nil && roundTripSucceeded && fileWriteSucceeded && fileReadSucceeded
            }

            var summary: String {
                if isHealthy { return "✅ App Group healthy" }
                var parts: [String] = []
                if containerURL == nil { parts.append("no container") }
                if !userDefaultsNonNil { parts.append("UD nil") }
                if !roundTripSucceeded { parts.append("UD round-trip FAIL") }
                if !fileWriteSucceeded { parts.append("file write FAIL") }
                if !fileReadSucceeded { parts.append("file read FAIL") }
                return "❌ " + parts.joined(separator: ", ")
            }
        }

        static func run(suiteName: String = SharedDefaults.suiteName) -> Result {
            var details: [String] = []

            // 1. Container URL — authoritative entitlement check.
            let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: suiteName)
            if let url = containerURL {
                details.append("containerURL: \(url.path)")
            } else {
                details.append("containerURL: nil (App Group NOT entitled for this process)")
            }

            // 2. UserDefaults(suiteName:) — unreliable alone, but we log it.
            let defaults = UserDefaults(suiteName: suiteName)
            let udNonNil = defaults != nil
            details.append("UserDefaults(suiteName:) -> \(udNonNil ? "non-nil" : "nil")")

            // 3. Write→read round-trip on the shared defaults (same process).
            var roundTrip = false
            if let defaults {
                let key = "_agHealthCheckCanary"
                let token = "check-\(Date().timeIntervalSince1970)"
                defaults.set(token, forKey: key)
                defaults.synchronize()
                let readback = defaults.string(forKey: key)
                roundTrip = (readback == token)
                details.append("UD canary wrote=\(token)")
                details.append("UD canary read =\(readback ?? "nil") match=\(roundTrip)")
            }

            // 4. Shared container file write/read — file-based fallback path.
            var fileWrite = false
            var fileRead = false
            if let container = containerURL {
                let url = container.appendingPathComponent("_agHealthCheck.json")
                let payload = ["ts": Date().timeIntervalSince1970]
                if let data = try? JSONSerialization.data(withJSONObject: payload) {
                    do {
                        try data.write(to: url, options: .atomic)
                        fileWrite = true
                        details.append("file write OK: \(url.lastPathComponent)")
                    } catch {
                        details.append("file write FAIL: \(error.localizedDescription)")
                    }
                }
                if fileWrite, let readData = try? Data(contentsOf: url),
                   (try? JSONSerialization.jsonObject(with: readData)) != nil {
                    fileRead = true
                    details.append("file read OK")
                } else if fileWrite {
                    details.append("file read FAIL")
                }
            }

            let result = Result(
                suiteName: suiteName,
                containerURL: containerURL,
                userDefaultsNonNil: udNonNil,
                roundTripSucceeded: roundTrip,
                fileWriteSucceeded: fileWrite,
                fileReadSucceeded: fileRead,
                details: details
            )

            logger.info("AppGroupHealthCheck(\(suiteName)): \(result.summary, privacy: .public)")
            for line in details {
                logger.info("  \(line, privacy: .public)")
            }
            return result
        }
    }
#endif

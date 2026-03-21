import Foundation
import os
import WatchConnectivity

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WatchSession")

class WatchSessionReceiver: NSObject, ObservableObject, WCSessionDelegate {
    private var authManager: WatchAuthManager?

    func activate(authManager: WatchAuthManager) {
        self.authManager = authManager
        guard WCSession.isSupported() else {
            logger.info("WCSession not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            logger.error("WCSession activation failed: \(error)")
        } else {
            logger.info("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    // Receive auth token from iPhone via transferUserInfo (guaranteed delivery)
    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let token = userInfo["authToken"] as? String else { return }
        logger.info("Received auth token from iPhone")

        Task { @MainActor in
            authManager?.updateToken(token)
        }
    }

    // Also handle real-time messages for immediate token delivery
    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let token = message["authToken"] as? String else { return }
        logger.info("Received auth token via message from iPhone")

        Task { @MainActor in
            authManager?.updateToken(token)
        }
    }
}

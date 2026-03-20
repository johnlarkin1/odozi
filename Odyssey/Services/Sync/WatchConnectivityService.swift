#if os(iOS)
import Foundation
import WatchConnectivity
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WatchConnectivity")

class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Send auth token to paired Apple Watch. Uses transferUserInfo for guaranteed delivery
    /// and also tries sendMessage for immediate delivery if watch is reachable.
    func sendToken(_ token: String) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            logger.warning("WCSession not activated, cannot send token")
            return
        }
        guard session.isPaired else {
            logger.info("No paired Apple Watch, skipping token transfer")
            return
        }

        // Guaranteed delivery (queued if watch is not reachable)
        session.transferUserInfo(["authToken": token])
        logger.info("Queued auth token transfer to watch")

        // Also try immediate delivery if reachable
        if session.isReachable {
            session.sendMessage(["authToken": token], replyHandler: nil) { error in
                logger.warning("Immediate token send failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            logger.error("WCSession activation failed: \(error)")
        } else {
            logger.info("WCSession activated (state: \(activationState.rawValue))")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated, reactivating")
        session.activate()
    }
}
#endif

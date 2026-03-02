import Foundation

enum ClerkConfiguration {
    static let publishableKey: String? = {
        guard let key = Bundle.main.infoDictionary?["ClerkPublishableKey"] as? String,
              !key.isEmpty,
              key != "$(CLERK_PUBLISHABLE_KEY)" else {
            assertionFailure("CLERK_PUBLISHABLE_KEY not set — copy Odyssey.xcconfig.example to Odyssey.xcconfig and configure it")
            return nil
        }
        return key
    }()

    // OAuth callback URL scheme (must match CFBundleURLTypes in Info.plist)
    static let callbackURLScheme = "odyssey"
}

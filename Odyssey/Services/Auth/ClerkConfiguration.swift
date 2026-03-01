import Foundation

enum ClerkConfiguration {
    // Clerk publishable key (safe to embed in binary — not a secret)
    // Replace with your actual Clerk publishable key from https://dashboard.clerk.com
    static let publishableKey = "pk_test_REPLACE_ME"

    // OAuth callback URL scheme (must match CFBundleURLTypes in Info.plist)
    static let callbackURLScheme = "odyssey"
}

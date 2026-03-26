import Foundation

enum ServerConfiguration {
    static let baseURL: String? = {
        guard let url = Bundle.main.infoDictionary?["OdysseyAPIBaseURL"] as? String,
              !url.isEmpty,
              url != "$(ODYSSEY_API_BASE_URL)"
        else {
            #if DEBUG
                print("⚠️ ODYSSEY_API_BASE_URL not set — copy Odyssey.xcconfig.example to Odyssey.xcconfig and configure it")
            #endif
            return nil
        }
        return url
    }()
}

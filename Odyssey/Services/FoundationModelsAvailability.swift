import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelsAvailability {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
        #else
        return false
        #endif
    }
}

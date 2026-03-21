import CryptoKit
import Foundation

enum RecoveryKeyGenerator {
    static func exportAsBase64(key: SymmetricKey) -> String {
        key.withUnsafeBytes { bytes in
            Data(bytes).base64EncodedString()
        }
    }

    static func importFromBase64(_ base64String: String) -> SymmetricKey? {
        guard let data = Data(base64Encoded: base64String),
              data.count == 32
        else { // 256 bits = 32 bytes
            return nil
        }
        return SymmetricKey(data: data)
    }
}

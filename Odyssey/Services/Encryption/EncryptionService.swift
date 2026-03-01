import Foundation
import CryptoKit

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidBase64
    case dataConversionFailed
}

actor EncryptionService {
    private var cachedKey: SymmetricKey?

    func getOrCreateKey() throws -> SymmetricKey {
        if let key = cachedKey {
            return key
        }

        if let existingKey = try KeychainService.retrieveKey() {
            cachedKey = existingKey
            return existingKey
        }

        let newKey = SymmetricKey(size: .bits256)
        try KeychainService.storeKey(newKey)
        cachedKey = newKey
        return newKey
    }

    func encrypt(_ plaintext: String) throws -> String {
        let key = try getOrCreateKey()
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.dataConversionFailed
        }

        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return combined.base64EncodedString()
    }

    func decrypt(_ ciphertext: String) throws -> String {
        let key = try getOrCreateKey()
        guard let data = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidBase64
        }

        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }

        return plaintext
    }

    func encryptDouble(_ value: Double) throws -> String {
        try encrypt(String(value))
    }

    func decryptDouble(_ ciphertext: String) throws -> Double {
        let decrypted = try decrypt(ciphertext)
        guard let value = Double(decrypted) else {
            throw EncryptionError.decryptionFailed
        }
        return value
    }

    func clearCachedKey() {
        cachedKey = nil
    }
}

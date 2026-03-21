import CryptoKit
@testable import Odyssey
import XCTest

final class EncryptionServiceTests: XCTestCase {
    // MARK: - EncryptionService Tests

    func testEncryptDecryptRoundtrip() async throws {
        let service = EncryptionService()
        let plaintext = "This is a secret journal entry"

        let ciphertext = try await service.encrypt(plaintext)
        let decrypted = try await service.decrypt(ciphertext)

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertNotEqual(ciphertext, plaintext)
    }

    func testEncryptDecryptEmptyString() async throws {
        let service = EncryptionService()
        let plaintext = ""

        let ciphertext = try await service.encrypt(plaintext)
        let decrypted = try await service.decrypt(ciphertext)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptUnicode() async throws {
        let service = EncryptionService()
        let plaintext = "Feeling grateful today! 🌟 Merci beaucoup 日本語"

        let ciphertext = try await service.encrypt(plaintext)
        let decrypted = try await service.decrypt(ciphertext)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptProducesDifferentCiphertextEachTime() async throws {
        let service = EncryptionService()
        let plaintext = "Same text"

        let ciphertext1 = try await service.encrypt(plaintext)
        let ciphertext2 = try await service.encrypt(plaintext)

        // AES-GCM uses random nonces, so ciphertexts should differ
        XCTAssertNotEqual(ciphertext1, ciphertext2)

        // Both should decrypt to the same plaintext
        let decrypted1 = try await service.decrypt(ciphertext1)
        let decrypted2 = try await service.decrypt(ciphertext2)
        XCTAssertEqual(decrypted1, plaintext)
        XCTAssertEqual(decrypted2, plaintext)
    }

    func testDecryptInvalidBase64Throws() async {
        let service = EncryptionService()

        do {
            _ = try await service.decrypt("not-valid-base64!!!")
            XCTFail("Expected decryption to throw")
        } catch {
            // Expected
        }
    }

    func testEncryptDecryptDouble() async throws {
        let service = EncryptionService()
        let value = 40.7128

        let ciphertext = try await service.encryptDouble(value)
        let decrypted = try await service.decryptDouble(ciphertext)

        XCTAssertEqual(decrypted, value, accuracy: 0.0001)
    }

    func testEncryptDecryptNegativeDouble() async throws {
        let service = EncryptionService()
        let value = -73.9352

        let ciphertext = try await service.encryptDouble(value)
        let decrypted = try await service.decryptDouble(ciphertext)

        XCTAssertEqual(decrypted, value, accuracy: 0.0001)
    }

    // MARK: - RecoveryKeyGenerator Tests

    func testRecoveryKeyExportImportRoundtrip() {
        let originalKey = SymmetricKey(size: .bits256)
        let base64 = RecoveryKeyGenerator.exportAsBase64(key: originalKey)
        let importedKey = RecoveryKeyGenerator.importFromBase64(base64)

        XCTAssertNotNil(importedKey)

        // Verify the keys are identical by encrypting/decrypting
        let testData = Data("test".utf8)
        // swiftlint:disable:next force_try
        let sealedBox = try! AES.GCM.seal(testData, using: originalKey)
        // swiftlint:disable:next force_try
        let decrypted = try! AES.GCM.open(sealedBox, using: importedKey!)
        XCTAssertEqual(String(data: decrypted, encoding: .utf8), "test")
    }

    func testRecoveryKeyImportInvalidBase64ReturnsNil() {
        let result = RecoveryKeyGenerator.importFromBase64("not-valid")
        XCTAssertNil(result)
    }

    func testRecoveryKeyImportWrongSizeReturnsNil() {
        // 16 bytes instead of 32
        let shortData = Data(repeating: 0, count: 16)
        let result = RecoveryKeyGenerator.importFromBase64(shortData.base64EncodedString())
        XCTAssertNil(result)
    }

    func testRecoveryKeyExportProducesValidBase64() {
        let key = SymmetricKey(size: .bits256)
        let base64 = RecoveryKeyGenerator.exportAsBase64(key: key)

        XCTAssertNotNil(Data(base64Encoded: base64))
        // 32 bytes = 44 base64 chars (with padding)
        XCTAssertEqual(Data(base64Encoded: base64)?.count, 32)
    }
}

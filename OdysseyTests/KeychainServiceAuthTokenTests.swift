@testable import Odyssey
import XCTest

final class KeychainServiceAuthTokenTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        try? KeychainService.deleteAuthToken()
    }

    func testStoreAndRetrieveAuthToken() throws {
        let token = "test-jwt-token-abc123"
        try KeychainService.storeAuthToken(token)
        let retrieved = try KeychainService.retrieveAuthToken()
        XCTAssertEqual(retrieved, token)
    }

    func testRetrieveAuthTokenWhenEmpty() throws {
        try KeychainService.deleteAuthToken()
        let retrieved = try KeychainService.retrieveAuthToken()
        XCTAssertNil(retrieved)
    }

    func testDeleteAuthToken() throws {
        let token = "token-to-delete"
        try KeychainService.storeAuthToken(token)
        try KeychainService.deleteAuthToken()
        let retrieved = try KeychainService.retrieveAuthToken()
        XCTAssertNil(retrieved)
    }

    func testOverwriteAuthToken() throws {
        try KeychainService.storeAuthToken("first-token")
        try KeychainService.storeAuthToken("second-token")
        let retrieved = try KeychainService.retrieveAuthToken()
        XCTAssertEqual(retrieved, "second-token")
    }
}

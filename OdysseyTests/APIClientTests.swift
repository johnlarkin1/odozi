@testable import Odyssey
import XCTest

final class APIClientTests: XCTestCase {
    private let client = APIClient(baseURL: "https://api.example.com")

    // MARK: - buildRequest

    func testBuildRequestSetsURL() async throws {
        let request = try await client.buildRequest(path: "/entries", method: "GET", token: "tok")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/entries")
    }

    func testBuildRequestSetsAuthHeader() async throws {
        let request = try await client.buildRequest(path: "/entries", method: "GET", token: "my-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer my-token")
    }

    func testBuildRequestSetsHTTPMethod() async throws {
        let request = try await client.buildRequest(path: "/entries", method: "DELETE", token: "tok")
        XCTAssertEqual(request.httpMethod, "DELETE")
    }

    func testBuildRequestThrowsForInvalidURL() async {
        let badClient = APIClient(baseURL: "")
        do {
            _ = try await badClient.buildRequest(path: "", method: "GET", token: "tok")
            XCTFail("Should throw invalidURL")
        } catch let error as APIError {
            if case .invalidURL = error {
                // expected
            } else {
                XCTFail("Expected invalidURL, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - validateResponse

    func testValidateResponse200NoThrow() async throws {
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        try await client.validateResponse(response)
    }

    func testValidateResponse299NoThrow() async throws {
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 299, httpVersion: nil, headerFields: nil)!
        try await client.validateResponse(response)
    }

    func testValidateResponse401ThrowsUnauthorized() async {
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        do {
            try await client.validateResponse(response)
            XCTFail("Should throw")
        } catch let error as APIError {
            if case .unauthorized = error {
                // expected
            } else {
                XCTFail("Expected unauthorized, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidateResponse429ThrowsRateLimited() async {
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 429, httpVersion: nil, headerFields: nil)!
        do {
            try await client.validateResponse(response)
            XCTFail("Should throw")
        } catch let error as APIError {
            if case .rateLimited = error {
                // expected
            } else {
                XCTFail("Expected rateLimited, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidateResponse500ThrowsServerError() async {
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        do {
            try await client.validateResponse(response)
            XCTFail("Should throw")
        } catch let error as APIError {
            if case let .serverError(code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - APIError descriptions

    func testAPIErrorDescriptions() {
        let cases: [APIError] = [
            .unauthorized,
            .rateLimited,
            .serverError(500),
            .invalidURL,
            .decodingError(NSError(domain: "", code: 0)),
            .networkError(NSError(domain: "", code: 0))
        ]
        for error in cases {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
        }
    }
}

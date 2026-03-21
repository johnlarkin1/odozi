import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case rateLimited
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .rateLimited:
            return "Too many requests. Please try again later."
        case let .serverError(code):
            return "Server error (\(code)). Please try again."
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to process server response."
        case .invalidURL:
            return "Invalid API configuration."
        }
    }
}

actor APIClient {
    private let baseURL: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: String = ServerConfiguration.baseURL ?? "") {
        self.baseURL = baseURL
        session = URLSession.shared
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func uploadEntries(_ payload: SyncUploadPayload, token: String) async throws -> SyncUploadResponse {
        let request = try buildRequest(
            path: "/entries",
            method: "POST",
            token: token,
            body: payload
        )

        return try await execute(request)
    }

    func fetchEntries(since: Date?, cursor: String? = nil, token: String) async throws -> SyncDownloadResponse {
        var params: [String] = []
        if let since {
            let formatter = ISO8601DateFormatter()
            params.append("since=\(formatter.string(from: since))")
        }
        if let cursor {
            params.append("cursor=\(cursor)")
        }
        params.append("limit=200")
        let path = "/entries" + (params.isEmpty ? "" : "?" + params.joined(separator: "&"))

        let request = try buildRequest(
            path: path,
            method: "GET",
            token: token
        )

        return try await execute(request)
    }

    func deleteEntry(date: String, token: String) async throws {
        let request = try buildRequest(
            path: "/entries/\(date)",
            method: "DELETE",
            token: token
        )

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func deleteAccount(token: String) async throws {
        let request = try buildRequest(
            path: "/account",
            method: "DELETE",
            token: token
        )

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Private

    private func buildRequest<T: Encodable>(
        path: String,
        method: String,
        token: String,
        body: T
    ) throws -> URLRequest {
        var request = try buildRequest(path: path, method: method, token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func buildRequest(
        path: String,
        method: String,
        token: String
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        try validateResponse(response)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}

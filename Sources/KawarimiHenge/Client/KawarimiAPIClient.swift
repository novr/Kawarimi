import Foundation
import KawarimiCore

/// Includes a short body prefix in `localizedDescription` when present so failures are easier to diagnose.
public struct KawarimiAPIError: Error, LocalizedError, Sendable {
    public var statusCode: Int
    public var data: Data?

    public init(statusCode: Int, data: Data? = nil) {
        self.statusCode = statusCode
        self.data = data
    }

    public var errorDescription: String? {
        var msg = "HTTP \(statusCode)"
        if let data = data, let body = String(data: data, encoding: .utf8), !body.isEmpty {
            let snippet = body.prefix(200)
            msg += " — \(snippet)"
        }
        return msg
    }
}

/// Appends `__kawarimi/...` under `baseURL` (include the API mount point in the base URL).
public struct KawarimiAPIClient: Sendable {
    public var baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private func validateHTTPStatus(_ response: URLResponse?, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw KawarimiAPIError(statusCode: http.statusCode, data: data)
        }
    }

    public func fetchSpec<T: Decodable & Sendable>(as type: T.Type) async throws -> T {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("spec")
        let (data, response) = try await session.data(from: url)
        try validateHTTPStatus(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func fetchOverrides() async throws -> [MockOverride] {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("status")
        let (data, response) = try await session.data(from: url)
        try validateHTTPStatus(response, data: data)
        return try JSONDecoder().decode([MockOverride].self, from: data)
    }

    public func configure(override: MockOverride) async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("configure")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(override)
        let (data, response) = try await session.data(for: request)
        try validateHTTPStatus(response, data: data)
    }

    public func reset() async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("reset")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        try validateHTTPStatus(response, data: nil)
    }
}

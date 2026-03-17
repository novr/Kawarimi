import Foundation
import KawarimiCore

/// HTTP エラー（4xx/5xx）。レスポンス body の先頭を errorDescription に含める。
public struct KawarimiAPIError: Error, LocalizedError, Sendable {
    public var statusCode: Int
    public var data: Data?

    public var errorDescription: String? {
        var msg = "HTTP \(statusCode)"
        if let data = data, let body = String(data: data, encoding: .utf8), !body.isEmpty {
            let snippet = body.prefix(200)
            msg += " — \(snippet)"
        }
        return msg
    }
}

/// Henge API（`/__kawarimi/*`）用クライアント。Spec はジェネリックでデコードする。
public struct KawarimiAPIClient: Sendable {
    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    private func validateHTTPStatus(_ response: URLResponse?, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw KawarimiAPIError(statusCode: http.statusCode, data: data)
        }
    }

    /// GET /__kawarimi/spec を取得し、指定した型でデコードする。生成された SpecResponse を渡す。
    public func fetchSpec<T: Decodable & Sendable>(as type: T.Type) async throws -> T {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("spec")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateHTTPStatus(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// GET /__kawarimi/status を取得し、[MockOverride] として返す。
    public func fetchOverrides() async throws -> [MockOverride] {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("status")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateHTTPStatus(response, data: data)
        return try JSONDecoder().decode([MockOverride].self, from: data)
    }

    /// POST /__kawarimi/configure でオーバーライドを送信する。
    public func configure(override: MockOverride) async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("configure")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(override)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPStatus(response, data: data)
    }

    /// POST /__kawarimi/reset で全オーバーライドをクリアする。
    public func reset() async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("reset")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateHTTPStatus(response, data: nil)
    }
}

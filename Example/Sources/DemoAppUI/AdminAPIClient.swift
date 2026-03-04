import DemoAPI
import Foundation

struct SpecResponse: Codable {
    var meta: KawarimiSpec.Meta
    var endpoints: [KawarimiSpec.Endpoint]
}

struct MockOverrideDTO: Codable {
    var path: String
    var method: String
    var statusCode: Int
    var isEnabled: Bool
    var exampleId: String?
    var mockId: String?
}

enum AdminAPIError: Error, LocalizedError {
    case httpError(statusCode: Int, data: Data?)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, _):
            return "HTTP \(code)"
        }
    }
}

struct AdminAPIClient {
    var baseURL: URL

    private func validateHTTPStatus(_ response: URLResponse?, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw AdminAPIError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    func fetchSpec() async throws -> SpecResponse {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("spec")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateHTTPStatus(response, data: data)
        return try JSONDecoder().decode(SpecResponse.self, from: data)
    }

    func fetchStatus() async throws -> [MockOverrideDTO] {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("status")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validateHTTPStatus(response, data: data)
        return try JSONDecoder().decode([MockOverrideDTO].self, from: data)
    }

    func configure(_ override: MockOverrideDTO) async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("configure")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(override)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPStatus(response, data: data)
    }

    func reset() async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("reset")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateHTTPStatus(response, data: nil)
    }
}

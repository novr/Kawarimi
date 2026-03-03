import Foundation

struct SpecMeta: Codable {
    var title: String
    var version: String
    var description: String?
    var serverURL: String
}

struct SpecMockResponse: Codable {
    var statusCode: Int
    var contentType: String
    var body: String
    var exampleId: String?
    var summary: String?
    var description: String?
}

struct SpecEndpoint: Codable {
    var path: String
    var method: String
    var operationId: String
    var responses: [SpecMockResponse]
}

struct SpecResponse: Codable {
    var meta: SpecMeta
    var endpoints: [SpecEndpoint]
}

struct MockOverrideDTO: Codable {
    var path: String
    var method: String
    var statusCode: Int
    var isEnabled: Bool
    var mockId: String?
}

struct AdminAPIClient {
    var baseURL: URL

    func fetchSpec() async throws -> SpecResponse {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("spec")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SpecResponse.self, from: data)
    }

    func fetchStatus() async throws -> [MockOverrideDTO] {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("status")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([MockOverrideDTO].self, from: data)
    }

    func configure(_ override: MockOverrideDTO) async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("configure")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(override)
        _ = try await URLSession.shared.data(for: request)
    }

    func reset() async throws {
        let url = baseURL.appendingPathComponent("__kawarimi").appendingPathComponent("reset")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await URLSession.shared.data(for: request)
    }
}

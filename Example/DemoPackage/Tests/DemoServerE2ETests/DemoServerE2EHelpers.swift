#if os(macOS) || os(Linux)
import DemoAPI
import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum DemoServerE2EConstants {
    static let exampleIdHeader = "X-Kawarimi-Example-Id"
    static let mockOverrideMaxBodyLength = 1_000_000
}

struct GreetingJSON: Decodable, Equatable {
    let message: String
}

struct ItemJSON: Decodable, Equatable {
    let id: String
    let name: String
}

enum DemoServerE2EJSON {
    private static let decoder = JSONDecoder()

    static func decodeGreeting(from data: Data) throws -> GreetingJSON {
        try decoder.decode(GreetingJSON.self, from: data)
    }

    static func decodeItems(from data: Data) throws -> [ItemJSON] {
        try decoder.decode([ItemJSON].self, from: data)
    }

    static func decodeItem(from data: Data) throws -> ItemJSON {
        try decoder.decode(ItemJSON.self, from: data)
    }

    static func decodeSpec(from data: Data) throws -> SpecResponse {
        try decoder.decode(SpecResponse.self, from: data)
    }
}

enum DemoServerE2EHTTPChecks {
    static func isJSONContentType(_ response: HTTPURLResponse) -> Bool {
        let value = response.value(forHTTPHeaderField: "Content-Type") ?? ""
        return value.lowercased().contains("application/json")
    }
}

extension DemoServerHTTP {
    static func get(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws -> (HTTPURLResponse, Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return try await data(for: request)
    }

    static func post(
        _ url: URL,
        body: Data,
        contentType: String?
    ) async throws -> (HTTPURLResponse, Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body
        return try await data(for: request)
    }
}
#endif

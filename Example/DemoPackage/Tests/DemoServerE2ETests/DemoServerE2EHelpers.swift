#if os(macOS) || os(Linux)
import DemoAPI
import Foundation
import KawarimiCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum DemoServerE2EConstants {
    static let exampleIdHeader = "X-Kawarimi-Example-Id"
}

struct GreetingJSON: Decodable, Equatable {
    let message: String
}

struct ItemJSON: Decodable, Equatable {
    let id: String
    let name: String
}

struct ErrorJSON: Decodable, Equatable {
    let code: String
    let message: String
}

enum DemoServerE2EJSON {
    private static let decoder = JSONDecoder()

    static func decodeGreeting(from data: Data) throws -> GreetingJSON {
        try decoder.decode(GreetingJSON.self, from: data)
    }

    static func decodeError(from data: Data) throws -> ErrorJSON {
        try decoder.decode(ErrorJSON.self, from: data)
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

    static func decodeHengeSpec(from data: Data) throws -> HengeSpecSnapshot {
        try decoder.decode(HengeSpecSnapshot.self, from: data)
    }

    static func decodeOverrides(from data: Data) throws -> [MockOverride] {
        try decoder.decode([MockOverride].self, from: data)
    }
}

enum DemoServerE2EHTTPChecks {
    static func isJSONContentType(_ response: HTTPURLResponse) -> Bool {
        let value = response.value(forHTTPHeaderField: "Content-Type") ?? ""
        return value.lowercased().contains("application/json")
    }
}
#endif

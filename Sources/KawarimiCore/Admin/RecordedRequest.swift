import Foundation

/// One captured inbound request on the Spy API (`GET …/__kawarimi/requests`).
public struct RecordedRequest: Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let method: String
    public let path: String
    public let queryItems: [RecordedQueryItem]
    public let headers: [String: String]
    public let body: String?
    public let matchedOperationId: String?
    public let action: RecordedProxyAction
    public let responseStatusCode: Int?

    public init(
        id: UUID,
        timestamp: Date,
        method: String,
        path: String,
        queryItems: [RecordedQueryItem],
        headers: [String: String],
        body: String?,
        matchedOperationId: String?,
        action: RecordedProxyAction,
        responseStatusCode: Int?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.matchedOperationId = matchedOperationId
        self.action = action
        self.responseStatusCode = responseStatusCode
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, method, path, queryItems, headers, body, matchedOperationId, action, responseStatusCode
    }

    /// Optionals are written as explicit `null` so JS-based E2E runners can tell "unknown" from a missing key.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(method, forKey: .method)
        try container.encode(path, forKey: .path)
        try container.encode(queryItems, forKey: .queryItems)
        try container.encode(headers, forKey: .headers)
        try container.encode(body, forKey: .body)
        try container.encode(matchedOperationId, forKey: .matchedOperationId)
        try container.encode(action, forKey: .action)
        try container.encode(responseStatusCode, forKey: .responseStatusCode)
    }
}

public struct RecordedQueryItem: Codable, Sendable, Equatable {
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }

    private enum CodingKeys: String, CodingKey {
        case name, value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
    }
}

public enum RecordedProxyAction: String, Codable, Sendable, Equatable {
    case mock
    case forward
    case passthrough
}

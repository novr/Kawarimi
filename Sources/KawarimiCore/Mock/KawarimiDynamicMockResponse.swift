import Foundation

public struct KawarimiDynamicMockResponse: Sendable, Equatable {
    public var statusCode: Int
    public var body: String
    public var contentType: String

    public init(statusCode: Int, body: String, contentType: String) {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
    }
}

/// Resolves the HTTP payload for a matched ``MockOverride`` against a generated ``KawarimiMockResponseResolver/NestedResponseMap``.
public enum KawarimiDynamicMockResponseResolver {
    public static func resolve(
        override: MockOverride,
        responseMap: KawarimiMockResponseResolver.NestedResponseMap,
        methodUppercased: String
    ) -> KawarimiDynamicMockResponse {
        let body: String
        let contentType: String
        if override.hasEffectiveCustomBody, let customBody = override.body {
            body = customBody
            contentType = override.contentType ?? "application/json"
        } else if let entry = KawarimiMockResponseResolver.lookup(
            map: responseMap,
            methodUppercased: methodUppercased,
            path: override.path,
            statusCode: override.statusCode,
            exampleId: override.exampleId
        ) {
            body = entry.body
            contentType = entry.contentType
        } else {
            body = "{}"
            contentType = override.contentType ?? "application/json"
        }
        return KawarimiDynamicMockResponse(
            statusCode: override.statusCode,
            body: body,
            contentType: contentType
        )
    }
}

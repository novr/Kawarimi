import Foundation

/// Keys for `KawarimiSpec.responseMap` inner dictionaries (`[status: [exampleKey: body]]`).
public enum KawarimiExampleIds {
    /// **Reserved** map key for the unnamed / default JSON example when OpenAPI has no named `examples` map.
    ///
    /// Do not use `__default` as a key in OpenAPI `content.examples`; pick another name so it does not collide
    /// with this synthetic slot. Runtime lookup uses this key when ``responseMapLookupKey(forOverrideExampleId:)``
    /// is asked for `nil`/empty (and when an override stores the literal `"__default"`).
    public static let defaultResponseMapKey = "__default"

    /// Key used to look up `responseMap` from `MockOverride.exampleId`.
    /// `nil`, empty, or whitespace-only → ``defaultResponseMapKey``.
    public static func responseMapLookupKey(forOverrideExampleId exampleId: String?) -> String {
        guard let trimmed = exampleId?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return defaultResponseMapKey
        }
        return trimmed
    }
}

/// Looks up a mock body in a nested `responseMap` (method+path → status → example key).
public enum KawarimiMockResponseResolver {
    public typealias NestedResponseMap = [String: [Int: [String: (body: String, contentType: String)]]]

    public static func lookup(
        map: NestedResponseMap,
        methodUppercased: String,
        path: String,
        statusCode: Int,
        exampleId: String?
    ) -> (body: String, contentType: String)? {
        let routeKey = "\(methodUppercased):\(path)"
        let exampleKey = KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: exampleId)
        return map[routeKey]?[statusCode]?[exampleKey]
    }
}

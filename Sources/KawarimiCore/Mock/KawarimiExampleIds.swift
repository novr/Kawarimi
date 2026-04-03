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

/// Optional HTTP request headers interpreted by reference middleware (e.g. ``KawarimiInterceptorMiddleware`` in the Example app).
///
/// These are unrelated to ``MockOverride`` JSON on `POST …/configure`; they affect **per-request** choice among several enabled overrides for the same path and method.
public enum KawarimiMockRequestHeaders {
    /// Prefer enabled overrides whose effective example map key matches this value (same rules as ``KawarimiExampleIds/responseMapLookupKey(forOverrideExampleId:)``).
    ///
    /// Example: `success` matches an override with `exampleId` `"success"`; omit or use whitespace-only to apply no narrowing.
    public static let exampleId = "X-Kawarimi-Example-Id"

    /// Narrows `candidates` to overrides whose example key matches the header; if that set is empty, returns `candidates` unchanged.
    public static func filterOverrides(_ candidates: [MockOverride], exampleIdHeaderRaw: String?) -> [MockOverride] {
        guard let raw = exampleIdHeaderRaw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return candidates
        }
        let want = KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: raw)
        let narrowed = candidates.filter {
            KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: $0.exampleId) == want
        }
        return narrowed.isEmpty ? candidates : narrowed
    }
}

import Foundation
import KawarimiCore

enum OverrideListQueries {
    /// Status code of an enabled override for the row, or nil when following spec only.
    static func enabledStatusCode(for rowKey: EndpointRowKey, in overrides: [MockOverride]) -> Int? {
        for ov in overrides where ov.isEnabled && ov.method == rowKey.method && ov.path == rowKey.path {
            return ov.statusCode
        }
        return nil
    }

    static func endpoint(for rowKey: EndpointRowKey, in endpoints: [any SpecEndpointProviding]) -> (any SpecEndpointProviding)? {
        endpoints.first { EndpointRowKey($0) == rowKey }
    }

    static func defaultResponseStatusCode(for rowKey: EndpointRowKey, in endpoints: [any SpecEndpointProviding]) -> Int {
        endpoint(for: rowKey, in: endpoints)?.responseList.first?.statusCode ?? 200
    }

    static func enabledOverride(for rowKey: EndpointRowKey, statusCode: Int, exampleId: String?, in overrides: [MockOverride]) -> MockOverride? {
        overrides.first { ov in
            ov.isEnabled && ov.method == rowKey.method && ov.path == rowKey.path && ov.statusCode == statusCode
                && normalizedExampleId(ov.exampleId) == normalizedExampleId(exampleId)
        }
    }

    private static func normalizedExampleId(_ id: String?) -> String? {
        guard let t = id?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}

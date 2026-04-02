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

    static func enabledOverride(for rowKey: EndpointRowKey, statusCode: Int, in overrides: [MockOverride]) -> MockOverride? {
        overrides.first { $0.isEnabled && $0.method == rowKey.method && $0.path == rowKey.path && $0.statusCode == statusCode }
    }
}

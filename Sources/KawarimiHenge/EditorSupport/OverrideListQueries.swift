import Foundation
import KawarimiCore

enum OverrideListQueries {
    static func overrideMatchesRow(
        _ ov: MockOverride,
        rowKey: EndpointRowKey,
        pathPrefix: String,
        operationId: String?
    ) -> Bool {
        guard ov.method == rowKey.method else { return false }
        let na = ov.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let op = operationId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !na.isEmpty, !op.isEmpty, na == op { return true }
        let pa = KawarimiPath.aligned(path: ov.path, pathPrefix: pathPrefix)
        let pb = KawarimiPath.aligned(path: rowKey.path, pathPrefix: pathPrefix)
        return pa == pb
    }

    /// Enabled overrides for this path + method, ordered like the interceptor tie-break (first wins).
    static func primaryEnabledOverride(
        for rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> MockOverride? {
        let candidates = overrides.filter { ov in
            ov.isEnabled && overrideMatchesRow(ov, rowKey: rowKey, pathPrefix: pathPrefix, operationId: operationId)
        }
        return MockOverride.sortedForInterceptorTieBreak(candidates).first
    }

    /// Status code of the primary enabled override for the row, or nil when following spec only.
    static func enabledStatusCode(
        for rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> Int? {
        primaryEnabledOverride(for: rowKey, operationId: operationId, pathPrefix: pathPrefix, in: overrides)?.statusCode
    }

    static func endpoint(for rowKey: EndpointRowKey, in endpoints: [any SpecEndpointProviding]) -> (any SpecEndpointProviding)? {
        endpoints.first { EndpointRowKey($0) == rowKey }
    }

    static func defaultResponseStatusCode(for rowKey: EndpointRowKey, in endpoints: [any SpecEndpointProviding]) -> Int {
        endpoint(for: rowKey, in: endpoints)?.responseList.first?.statusCode ?? 200
    }

    static func enabledOverride(
        for rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        statusCode: Int,
        exampleId: String?,
        in overrides: [MockOverride]
    ) -> MockOverride? {
        overrides.first { ov in
            ov.isEnabled
                && overrideMatchesRow(ov, rowKey: rowKey, pathPrefix: pathPrefix, operationId: operationId)
                && ov.statusCode == statusCode
                && MockExamplePresentation.normalizedExampleId(ov.exampleId) == MockExamplePresentation.normalizedExampleId(exampleId)
        }
    }

    /// Any stored row for this operation + status + example (enabled or disabled).
    static func storedOverride(
        for rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        statusCode: Int,
        exampleId: String?,
        in overrides: [MockOverride]
    ) -> MockOverride? {
        overrides.first { ov in
            overrideMatchesRow(ov, rowKey: rowKey, pathPrefix: pathPrefix, operationId: operationId)
                && ov.statusCode == statusCode
                && MockExamplePresentation.normalizedExampleId(ov.exampleId) == MockExamplePresentation.normalizedExampleId(exampleId)
        }
    }

    /// True when the draft corresponds to a persisted override row (used for Spec chip vs disabled-row selection).
    static func hasStoredRowMatchingDraft(
        _ draft: MockOverride,
        rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> Bool {
        storedOverride(
            for: rowKey,
            operationId: operationId,
            pathPrefix: pathPrefix,
            statusCode: draft.statusCode,
            exampleId: draft.exampleId,
            in: overrides
        ) != nil
    }

    /// After refresh, re-select the same logical mock row (path string may differ from configure normalization).
    static func pinnedEnabledOverride(
        matching draft: MockOverride,
        rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> MockOverride? {
        if let o = enabledOverride(
            for: rowKey,
            operationId: operationId,
            pathPrefix: pathPrefix,
            statusCode: draft.statusCode,
            exampleId: draft.exampleId,
            in: overrides
        ) {
            return o
        }
        guard let opName = draft.name?.trimmingCharacters(in: .whitespacesAndNewlines), !opName.isEmpty else { return nil }
        return overrides.first { ov in
            ov.isEnabled
                && overrideMatchesRow(ov, rowKey: rowKey, pathPrefix: pathPrefix, operationId: operationId)
                && ov.statusCode == draft.statusCode
                && MockExamplePresentation.normalizedExampleId(ov.exampleId) == MockExamplePresentation.normalizedExampleId(draft.exampleId)
                && ov.name == opName
        }
    }

    /// Overrides for this operation whose status / example pair does not appear in the OpenAPI response list (enabled **and** disabled).
    static func customOverrides(
        for rowKey: EndpointRowKey,
        endpoint: any SpecEndpointProviding,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> [MockOverride] {
        let hits = overrides.filter { ov in
            overrideMatchesRow(ov, rowKey: rowKey, pathPrefix: pathPrefix, operationId: operationId)
        }
        return hits.filter { ov in
            !endpoint.responseList.contains { r in
                r.statusCode == ov.statusCode && MockExamplePresentation.exampleIdsEqual(r.exampleId, ov.exampleId)
            }
        }
    }

    static func specContainsResponse(
        _ endpoint: any SpecEndpointProviding,
        statusCode: Int,
        exampleId: String?
    ) -> Bool {
        endpoint.responseList.contains { r in
            r.statusCode == statusCode && MockExamplePresentation.exampleIdsEqual(r.exampleId, exampleId)
        }
    }
}

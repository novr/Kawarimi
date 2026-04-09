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

    static func draftRepresentsSpecOnlyRowForSave(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> Bool {
        guard !mock.isEnabled else { return false }
        guard mock.statusCode == (endpoint.responseList.first?.statusCode ?? 200) else { return false }
        guard MockExamplePresentation.normalizedExampleId(mock.exampleId) == nil else { return false }
        let bodyTrim = (mock.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ctTrim = (mock.contentType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if bodyTrim.isEmpty && ctTrim.isEmpty { return true }
        return mockBodyAndContentTypeMatchSpecTemplate(mock: mock, endpoint: endpoint)
    }

    // MARK: - Exclusive enabled row (same OpenAPI operation)

    /// Same `paths` entry + HTTP method (via `operationId` when both set, else aligned paths).
    static func sameOpenAPIOperation(_ a: MockOverride, _ b: MockOverride, pathPrefix: String) -> Bool {
        let na = a.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nb = b.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !na.isEmpty, !nb.isEmpty { return na == nb }
        let pa = KawarimiPath.aligned(path: a.path, pathPrefix: pathPrefix)
        let pb = KawarimiPath.aligned(path: b.path, pathPrefix: pathPrefix)
        return pa == pb
    }

    /// Same persisted row identity as `configure` / `remove` (path + method + status + example id).
    static func isSameOverrideRow(_ a: MockOverride, _ b: MockOverride, pathPrefix: String) -> Bool {
        guard a.method == b.method else { return false }
        guard a.statusCode == b.statusCode else { return false }
        guard MockExamplePresentation.exampleIdsEqual(a.exampleId, b.exampleId) else { return false }
        let pa = KawarimiPath.aligned(path: a.path, pathPrefix: pathPrefix)
        let pb = KawarimiPath.aligned(path: b.path, pathPrefix: pathPrefix)
        return pa == pb
    }

    /// When saving **`saved`** with **`isEnabled: true`**, each matching **other** enabled row for the same operation
    /// (including same status + different `exampleId`) should be turned off so only one mock is active.
    static func peerShouldBeDisabledWhenSavingEnabledRow(
        saved: MockOverride,
        peer: MockOverride,
        pathPrefix: String
    ) -> Bool {
        guard peer.isEnabled else { return false }
        guard saved.method == peer.method else { return false }
        guard sameOpenAPIOperation(saved, peer, pathPrefix: pathPrefix) else { return false }
        return !isSameOverrideRow(saved, peer, pathPrefix: pathPrefix)
    }

    // MARK: - Spec template matching (Save payload only)

    private static func mockBodyAndContentTypeMatchSpecTemplate(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> Bool {
        guard let specResp = endpoint.responseList.first(where: { r in
            r.statusCode == mock.statusCode && MockExamplePresentation.exampleIdsEqual(r.exampleId, mock.exampleId)
        }) else { return false }
        return bodiesAndContentTypesMatchSpec(mock: mock, spec: specResp)
    }

    private static func bodiesAndContentTypesMatchSpec(
        mock: MockOverride,
        spec: any SpecMockResponseProviding
    ) -> Bool {
        let mb = (mock.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let sb = spec.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyOK: Bool
        if mb.isEmpty, sb.isEmpty {
            bodyOK = true
        } else {
            bodyOK = bodiesLogicallyEqual(trimmedMock: mb, trimmedSpec: sb)
        }
        return bodyOK && contentTypesAligned(mockContentType: mock.contentType, specContentType: spec.contentType)
    }

    private static func bodiesLogicallyEqual(trimmedMock: String, trimmedSpec: String) -> Bool {
        if trimmedMock == trimmedSpec { return true }
        guard let dm = trimmedMock.data(using: .utf8),
              let ds = trimmedSpec.data(using: .utf8),
              let jm = try? JSONSerialization.jsonObject(with: dm),
              let js = try? JSONSerialization.jsonObject(with: ds) else {
            return false
        }
        return (jm as? NSObject)?.isEqual(js) ?? false
    }

    private static func contentTypesAligned(mockContentType: String?, specContentType: String) -> Bool {
        let m = (mockContentType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let s = specContentType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if m.isEmpty, s.isEmpty { return true }
        if m.isEmpty { return s == "application/json" || s.isEmpty }
        if s.isEmpty { return m == "application/json" || m.isEmpty }
        return m == s
    }
}

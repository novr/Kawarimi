import Foundation
import KawarimiCore

/// Stateless Henge explorer queries (row matching, primary/stored rows, Save/chip rules, persistable equality, peer-disable inputs).
package enum OverrideListQueries {
    // MARK: - Row matching & primary

    package static func overrideMatchesRow(
        _ ov: MockOverride,
        rowKey: EndpointRowKey,
        pathPrefix: String,
        operationId: String?
    ) -> Bool {
        MockOverrideRequestMatching.overrideMatchesOperation(
            ov,
            method: rowKey.method,
            operationPath: rowKey.path,
            operationID: operationId,
            pathPrefix: pathPrefix
        )
    }

    /// Enabled overrides for this path + method, ordered like the interceptor tie-break (first wins).
    package static func primaryEnabledOverride(
        for rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> MockOverride? {
        MockOverrideRequestMatching.primaryEnabledOverrideForOperation(
            in: overrides,
            method: rowKey.method,
            operationPath: rowKey.path,
            operationID: operationId,
            pathPrefix: pathPrefix
        )
    }

    /// Status code of the primary enabled override for the row, or nil when following spec only.
    package static func enabledStatusCode(
        for rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> Int? {
        primaryEnabledOverride(for: rowKey, operationId: operationId, pathPrefix: pathPrefix, in: overrides)?.statusCode
    }

    /// For **P** on spec-backed chips: when several `responseList` rows share `statusCode` + `exampleId`, picks the index whose template best matches the enabled override (same rules as template merge / save).
    package static func specResponseListIndexForPrimaryBadge(
        primary enabled: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> Int? {
        let list = endpoint.responseList
        let matching = list.indices.filter {
            list[$0].statusCode == enabled.statusCode
                && MockExamplePresentation.exampleIdsEqual(list[$0].exampleId, enabled.exampleId)
        }
        guard let first = matching.first else { return nil }
        if matching.count == 1 { return first }

        var winners: [Int] = []
        for i in matching where bodiesAndContentTypesMatchSpec(mock: enabled, spec: list[i]) {
            winners.append(i)
        }
        if winners.count == 1 { return winners[0] }

        // Identical templates or still ambiguous: align with `mergeResponseTemplate` (`first(where:)` order).
        return first
    }

    /// All **enabled** overrides for this OpenAPI operation (path/method or `operationId`), interceptor tie-break order.
    package static func enabledOverridesForOperation(
        rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> [MockOverride] {
        MockOverrideRequestMatching.matchingEnabledOverridesForOperation(
            in: overrides,
            method: rowKey.method,
            operationPath: rowKey.path,
            operationID: operationId,
            pathPrefix: pathPrefix
        )
    }

    /// More than one enabled row for the same operation (e.g. hand-edited config); interceptor uses tie-break order.
    package static func hasMultipleEnabledOverridesForOperation(
        rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> Bool {
        enabledOverridesForOperation(
            rowKey: rowKey,
            operationId: operationId,
            pathPrefix: pathPrefix,
            in: overrides
        ).count >= 2
    }

    /// All **disabled** overrides for this OpenAPI operation.
    package static func disabledOverridesForOperation(
        rowKey: EndpointRowKey,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> [MockOverride] {
        overrides.filter { ov in
            !ov.isEnabled
                && overrideMatchesRow(ov, rowKey: rowKey, pathPrefix: pathPrefix, operationId: operationId)
        }
    }

    // MARK: - Spec endpoint lookup

    package static func endpoint(for rowKey: EndpointRowKey, in endpoints: [any SpecEndpointProviding]) -> (any SpecEndpointProviding)? {
        endpoints.first { EndpointRowKey($0) == rowKey }
    }

    package static func defaultResponseStatusCode(for rowKey: EndpointRowKey, in endpoints: [any SpecEndpointProviding]) -> Int {
        endpoint(for: rowKey, in: endpoints)?.responseList.first?.statusCode ?? 200
    }

    // MARK: - Stored row lookup (status + example identity)

    package static func enabledOverride(
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
    package static func storedOverride(
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
                && MockExamplePresentation.exampleIdsEqual(ov.exampleId, exampleId)
        }
    }

    /// Stored row to delete for **Del** on the current chip — exact identity first, then legacy rows saved without `exampleId` but whose body matches the chip's OpenAPI template.
    package static func storedOverrideForDel(
        mock: MockOverride,
        rowKey: EndpointRowKey,
        endpoint: any SpecEndpointProviding,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> MockOverride? {
        if let exact = storedOverride(
            for: rowKey,
            operationId: operationId,
            pathPrefix: pathPrefix,
            statusCode: mock.statusCode,
            exampleId: mock.exampleId,
            in: overrides
        ) {
            return exact
        }
        guard let chipExampleId = MockExamplePresentation.normalizedExampleId(mock.exampleId) else { return nil }
        guard let specResp = endpoint.responseList.first(where: { r in
            r.statusCode == mock.statusCode
                && MockExamplePresentation.normalizedExampleId(r.exampleId) == chipExampleId
        }) else { return nil }
        return overrides.first { ov in
            overrideMatchesRow(ov, rowKey: rowKey, pathPrefix: pathPrefix, operationId: operationId)
                && ov.statusCode == mock.statusCode
                && MockExamplePresentation.normalizedExampleId(ov.exampleId) == nil
                && bodiesAndContentTypesMatchSpec(mock: ov, spec: specResp)
        }
    }

    /// Wire identity for ``POST …/__kawarimi/remove`` — uses the stored row's path / example id as persisted in `kawarimi.json`.
    package static func removeIdentity(for stored: MockOverride, operationId: String) -> MockOverride {
        MockOverride(
            name: stored.name ?? operationId,
            rowId: stored.rowId,
            path: stored.path,
            method: stored.method,
            statusCode: stored.statusCode,
            exampleId: stored.exampleId,
            isEnabled: false,
            body: nil,
            contentType: nil
        )
    }

    package static func hasStoredRowMatchingDraft(
        _ draft: MockOverride,
        rowKey: EndpointRowKey,
        endpoint: any SpecEndpointProviding,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> Bool {
        storedOverrideForDel(
            mock: draft,
            rowKey: rowKey,
            endpoint: endpoint,
            operationId: operationId,
            pathPrefix: pathPrefix,
            in: overrides
        ) != nil
    }

    /// After refresh, re-select the same logical mock row (path string may differ from configure normalization).
    package static func pinnedEnabledOverride(
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

    // MARK: - Custom responses (not in OpenAPI response list)

    /// Overrides for this operation whose status / example pair does not appear in the OpenAPI response list (enabled **and** disabled).
    package static func customOverrides(
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
            if isSpecFollowGhostRow(ov, endpoint: endpoint) {
                return false
            }
            return !endpoint.responseList.contains { r in
                r.statusCode == ov.statusCode && MockExamplePresentation.exampleIdsEqual(r.exampleId, ov.exampleId)
            }
        }
    }

    /// Disabled preset with no custom JSON for a documented status — not a supplemental chip (e.g. Spec-only Save residue with `exampleId: nil` on named-example operations).
    package static func isSpecFollowGhostRow(
        _ ov: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> Bool {
        guard !ov.isEnabled, !ov.hasEffectiveCustomBody else { return false }
        return endpoint.responseList.contains { $0.statusCode == ov.statusCode }
    }

    package static func specContainsResponse(
        _ endpoint: any SpecEndpointProviding,
        statusCode: Int,
        exampleId: String?
    ) -> Bool {
        endpoint.responseList.contains { r in
            r.statusCode == statusCode && MockExamplePresentation.exampleIdsEqual(r.exampleId, exampleId)
        }
    }

    // MARK: - Spec-shaped draft (chips & Save early exit)

    package static func draftRepresentsSpecOnlyRowForSave(
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
    package static func sameOpenAPIOperation(_ a: MockOverride, _ b: MockOverride, pathPrefix: String) -> Bool {
        let na = a.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nb = b.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !na.isEmpty, !nb.isEmpty { return na == nb }
        let pa = KawarimiPath.aligned(path: a.path, pathPrefix: pathPrefix)
        let pb = KawarimiPath.aligned(path: b.path, pathPrefix: pathPrefix)
        return pa == pb
    }

    /// Same persisted row identity as `configure` / `remove`:
    /// rowId first, then legacy identity (`path + method + status + exampleId`) when both rowIds are nil.
    package static func isSameOverrideRow(_ a: MockOverride, _ b: MockOverride, pathPrefix: String) -> Bool {
        let aRowId = MockOverride.normalizedRowId(a.rowId)
        let bRowId = MockOverride.normalizedRowId(b.rowId)
        if let aRowId, let bRowId {
            return aRowId == bRowId
        }
        guard aRowId == nil, bRowId == nil else { return false }
        guard a.method == b.method else { return false }
        guard a.statusCode == b.statusCode else { return false }
        guard MockExamplePresentation.exampleIdsEqual(a.exampleId, b.exampleId) else { return false }
        let pa = KawarimiPath.aligned(path: a.path, pathPrefix: pathPrefix)
        let pb = KawarimiPath.aligned(path: b.path, pathPrefix: pathPrefix)
        return pa == pb
    }

    /// When saving **`saved`** with **`isEnabled: true`**, each matching **other** enabled row for the same operation
    /// (including same status + different `exampleId`) should be turned off so only one mock is active.
    package static func peerShouldBeDisabledWhenSavingEnabledRow(
        saved: MockOverride,
        peer: MockOverride,
        pathPrefix: String
    ) -> Bool {
        guard peer.isEnabled else { return false }
        guard saved.method == peer.method else { return false }
        guard sameOpenAPIOperation(saved, peer, pathPrefix: pathPrefix) else { return false }
        return !isSameOverrideRow(saved, peer, pathPrefix: pathPrefix)
    }

    // MARK: - Persistable mock equality (UI “server diff” vs. resync canonical)

    /// Compares fields that align with a server override row after ``OverrideDetailDraft/resyncMockFromServer(overrides:endpoints:pathPrefix:)`` (JSON whitespace–tolerant; content types like ``contentTypesAligned``).
    package static func persistableMockConfigurationEqual(_ a: MockOverride, _ b: MockOverride) -> Bool {
        guard a.method == b.method else { return false }
        guard a.path == b.path else { return false }
        guard a.isEnabled == b.isEnabled else { return false }
        guard a.statusCode == b.statusCode else { return false }
        guard MockExamplePresentation.exampleIdsEqual(a.exampleId, b.exampleId) else { return false }
        guard a.delayMs == b.delayMs else { return false }
        let na = a.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nb = b.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard na == nb else { return false }
        let ab = (a.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let bb = (b.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyOK: Bool
        if ab.isEmpty, bb.isEmpty {
            bodyOK = true
        } else {
            bodyOK = bodiesLogicallyEqual(trimmedMock: ab, trimmedSpec: bb)
        }
        let ctOK =
            contentTypesAligned(mockContentType: a.contentType, specContentType: b.contentType ?? "")
            && contentTypesAligned(mockContentType: b.contentType, specContentType: a.contentType ?? "")
        return bodyOK && ctOK
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

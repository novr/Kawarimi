import Foundation
import KawarimiCore

/// Builds a **fresh** ``OverrideDetailDraft`` when the user opens an endpoint and there is **no** stashed draft for that row.
///
/// Owns the only policy sequence **placeholder → optional primary overlay → ``OverrideDetailDraft/resyncMockFromServer``**.
/// Without the primary overlay, a spec-shaped placeholder `(first spec status, nil example)` can match **`storedOverride`** to an unrelated **disabled** row that appears **earlier** in `kawarimi.json` than the **enabled primary**, so list **P**, chip selection, and body would disagree.
///
/// Documented in **docs/henge.md** (Override editor → Explorer state model → Draft bootstrap).
enum OverrideExplorerDraftBootstrap {
    /// Resolves the endpoint, builds the initial mock, runs one resync, and returns a clean draft; `nil` if the row key does not match any loaded endpoint.
    static func makeFreshDetail(
        rowKey: EndpointRowKey,
        pathPrefix: String,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride]
    ) -> OverrideDetailDraft? {
        guard let endpoint = OverrideListQueries.endpoint(for: rowKey, in: endpoints) else { return nil }
        let mock = initialMockBeforeResync(for: endpoint, pathPrefix: pathPrefix, overrides: overrides)
        var draft = OverrideDetailDraft(mock: mock, validationMessage: nil, isDirty: false)
        draft.resyncMockFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: pathPrefix)
        return draft
    }

    /// Spec-shaped placeholder, then—when the server has an enabled primary for this operation—overlays **statusCode**, **exampleId**, **isEnabled**, and **name** so the following resync hits the intended stored row.
    static func initialMockBeforeResync(
        for endpoint: any SpecEndpointProviding,
        pathPrefix: String,
        overrides: [MockOverride]
    ) -> MockOverride {
        var mock = MockDraftDefaults.specPlaceholder(for: endpoint)
        let opKey = EndpointRowKey(endpoint)
        if let primary = OverrideListQueries.primaryEnabledOverride(
            for: opKey,
            operationId: endpoint.operationId,
            pathPrefix: pathPrefix,
            in: overrides
        ) {
            mock.statusCode = primary.statusCode
            mock.exampleId = primary.exampleId
            mock.isEnabled = true
            mock.name = primary.name ?? endpoint.operationId
        }
        return mock
    }
}

import Foundation
import KawarimiCore

/// Per-endpoint editor draft (``mock``, ``isDirty``, ``pinnedNumberedResponseChip``). Sync via ``resyncMockFromServer``; first open via ``OverrideExplorerDraftBootstrap``.
package struct OverrideDetailDraft {
    package var mock: MockOverride
    package var validationMessage: String?
    package var isDirty: Bool
    package var pinnedNumberedResponseChip: Bool = false

    package init(mock: MockOverride, validationMessage: String?, isDirty: Bool = false) {
        self.mock = mock
        self.validationMessage = validationMessage
        self.isDirty = isDirty
    }

    package var endpointRowKey: EndpointRowKey {
        EndpointRowKey(method: mock.method, path: mock.path)
    }

    package mutating func resyncMockFromServer(
        overrides: [MockOverride],
        endpoints: [any SpecEndpointProviding],
        pathPrefix: String
    ) {
        pinnedNumberedResponseChip = false
        guard let endpoint = OverrideListQueries.endpoint(for: endpointRowKey, in: endpoints) else { return }
        let rowKey = EndpointRowKey(endpoint)
        let opId = endpoint.operationId

        if let exact = OverrideListQueries.storedOverride(
            for: rowKey,
            operationId: opId,
            pathPrefix: pathPrefix,
            statusCode: mock.statusCode,
            exampleId: mock.exampleId,
            in: overrides
        ) {
            mock.isEnabled = exact.isEnabled
            mock.statusCode = exact.statusCode
            mock.exampleId = exact.exampleId
            mock.delayMs = exact.delayMs
            mock.failureMode = exact.failureMode
            mock.name = exact.name ?? endpoint.operationId
            if exact.hasEffectiveCustomBody {
                mock.body = exact.body
                mock.contentType = exact.contentType
            } else {
                mergeResponseTemplate(
                    endpoint: endpoint,
                    overrides: overrides,
                    pathPrefix: pathPrefix,
                    statusCode: exact.statusCode,
                    into: &mock
                )
            }
            return
        }

        if mock.isEnabled,
           let pinned = OverrideListQueries.pinnedEnabledOverride(
            matching: mock,
            rowKey: rowKey,
            operationId: opId,
            pathPrefix: pathPrefix,
            in: overrides
           ) {
            mock.statusCode = pinned.statusCode
            mock.exampleId = pinned.exampleId
            mock.delayMs = pinned.delayMs
            mock.failureMode = pinned.failureMode
            mock.name = pinned.name ?? endpoint.operationId
            mergeResponseTemplate(
                endpoint: endpoint,
                overrides: overrides,
                pathPrefix: pathPrefix,
                statusCode: pinned.statusCode,
                into: &mock
            )
            return
        }

        if mock.isEnabled {
            let candidates = overrides.filter {
                $0.isEnabled && OverrideListQueries.overrideMatchesRow($0, rowKey: rowKey, pathPrefix: pathPrefix, operationId: opId)
            }
            if let ov = MockOverride.sortedForInterceptorTieBreak(candidates).first {
                mock.statusCode = ov.statusCode
                mock.exampleId = ov.exampleId
                mock.delayMs = ov.delayMs
                mock.failureMode = ov.failureMode
                mock.name = ov.name ?? endpoint.operationId
                mergeResponseTemplate(
                    endpoint: endpoint,
                    overrides: overrides,
                    pathPrefix: pathPrefix,
                    statusCode: ov.statusCode,
                    into: &mock
                )
                return
            }
        }

        mock.isEnabled = false
        mock.statusCode = OverrideListQueries.defaultResponseStatusCode(for: rowKey, in: endpoints)
        mock.exampleId = nil
        mock.body = nil
        mock.contentType = nil
        mock.delayMs = nil
        mock.failureMode = nil
        mock.name = endpoint.operationId
    }

    /// True when the draft’s mock differs from what ``resyncMockFromServer`` would produce for the same `overrides` snapshot (ignores ``pinnedNumberedResponseChip``, ``validationMessage``, and ``isDirty``).
    package func persistableMockDiffersFromServer(
        overrides: [MockOverride],
        endpoints: [any SpecEndpointProviding],
        pathPrefix: String
    ) -> Bool {
        var probe = self
        probe.resyncMockFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: pathPrefix)
        return !OverrideListQueries.persistableMockConfigurationEqual(mock, probe.mock)
    }
}

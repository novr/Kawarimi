import Foundation
import KawarimiCore

struct OverrideDetailDraft {
    var mock: MockOverride
    var validationMessage: String?
    var isDirty: Bool

    init(mock: MockOverride, validationMessage: String?, isDirty: Bool = false) {
        self.mock = mock
        self.validationMessage = validationMessage
        self.isDirty = isDirty
    }

    var endpointRowKey: EndpointRowKey {
        EndpointRowKey(method: mock.method, path: mock.path)
    }

    mutating func resyncMockFromServer(
        overrides: [MockOverride],
        endpoints: [any SpecEndpointProviding],
        pathPrefix: String
    ) {
        let draftRowKey = endpointRowKey
        guard let endpoint = OverrideListQueries.endpoint(for: draftRowKey, in: endpoints) else { return }
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
            mock.isEnabled = true
            mock.statusCode = pinned.statusCode
            mock.exampleId = pinned.exampleId
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

        // When the draft is off (or no exact row), do not jump to another example's enabled row — that
        // made the default/spec chip look like its `isEnabled` flipped after selection or refresh.
        if mock.isEnabled {
            let candidates = overrides.filter {
                $0.isEnabled && OverrideListQueries.overrideMatchesRow($0, rowKey: rowKey, pathPrefix: pathPrefix, operationId: opId)
            }
            if let ov = MockOverride.sortedForInterceptorTieBreak(candidates).first {
                mock.isEnabled = true
                mock.statusCode = ov.statusCode
                mock.exampleId = ov.exampleId
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
        mock.name = endpoint.operationId
    }
}

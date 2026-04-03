import Foundation
import KawarimiCore

/// Prefers a real body from a stored override (enabled or disabled) for the same path, method, status, and example over the spec example.
func mergeResponseTemplate(
    endpoint: any SpecEndpointProviding,
    overrides: [MockOverride],
    pathPrefix: String,
    statusCode code: Int,
    into mock: inout MockOverride
) {
    let key = EndpointRowKey(endpoint)
    let ex = mock.exampleId
    if let ov = OverrideListQueries.storedOverride(
        for: key,
        operationId: endpoint.operationId,
        pathPrefix: pathPrefix,
        statusCode: code,
        exampleId: ex,
        in: overrides
    ),
       ov.hasEffectiveCustomBody, let body = ov.body {
        mock.body = body
        mock.contentType = ov.contentType ?? "application/json"
        return
    }
    if let resp = endpoint.responseList.first(where: { matchesSpecExample($0, statusCode: code, exampleId: ex) }) {
        mock.body = resp.body
        mock.contentType = resp.contentType
    } else {
        mock.body = nil
        mock.contentType = nil
        // Extra example ids (not listed in the spec) still share an HTTP status with the operation: seed body from the first spec row for that status.
        if let fallback = endpoint.responseList.first(where: { $0.statusCode == code }) {
            mock.body = fallback.body
            mock.contentType = fallback.contentType
        }
    }
}

private func matchesSpecExample(_ resp: any SpecMockResponseProviding, statusCode: Int, exampleId: String?) -> Bool {
    guard resp.statusCode == statusCode else { return false }
    return MockExamplePresentation.exampleIdsEqual(resp.exampleId, exampleId)
}

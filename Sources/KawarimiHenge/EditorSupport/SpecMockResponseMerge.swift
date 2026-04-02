import Foundation
import KawarimiCore

/// Prefers a real body from an enabled override for the same path, method, status, and example over the spec example.
func mergeResponseTemplate(
    endpoint: any SpecEndpointProviding,
    overrides: [MockOverride],
    statusCode code: Int,
    into mock: inout MockOverride
) {
    let key = EndpointRowKey(endpoint)
    let ex = mock.exampleId
    if let ov = OverrideListQueries.enabledOverride(for: key, statusCode: code, exampleId: ex, in: overrides),
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
    }
}

private func matchesSpecExample(_ resp: any SpecMockResponseProviding, statusCode: Int, exampleId: String?) -> Bool {
    guard resp.statusCode == statusCode else { return false }
    let a = resp.exampleId.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
    let b = exampleId.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
    return a == b
}

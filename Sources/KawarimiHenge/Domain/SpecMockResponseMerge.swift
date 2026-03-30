import KawarimiCore

/// Prefers a real body from an enabled override for the same path, method, and status over the spec example.
func mergeResponseTemplate(
    endpoint: any SpecEndpointProviding,
    overrides: [MockOverride],
    statusCode code: Int,
    into mock: inout MockOverride
) {
    let key = EndpointRowKey(endpoint)
    if let ov = OverrideListQueries.enabledOverride(for: key, statusCode: code, in: overrides),
       ov.hasEffectiveCustomBody, let body = ov.body {
        mock.body = body
        mock.contentType = ov.contentType ?? "application/json"
        return
    }
    if let resp = endpoint.responseList.first(where: { $0.statusCode == code }) {
        mock.body = resp.body
        mock.contentType = resp.contentType
    } else {
        mock.body = nil
        mock.contentType = nil
    }
}

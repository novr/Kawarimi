import KawarimiCore

struct OverrideDetailDraft {
    var mock: MockOverride
    var validationMessage: String?
    var isDirty: Bool = false

    var endpointRowKey: EndpointRowKey {
        EndpointRowKey(method: mock.method, path: mock.path)
    }

    mutating func resyncMockFromServer(overrides: [MockOverride], endpoints: [any SpecEndpointProviding]) {
        let rowKey = endpointRowKey
        if let code = OverrideListQueries.enabledStatusCode(for: rowKey, in: overrides) {
            mock.isEnabled = true
            mock.statusCode = code
            if let ep = OverrideListQueries.endpoint(for: rowKey, in: endpoints) {
                mergeResponseTemplate(endpoint: ep, overrides: overrides, statusCode: code, into: &mock)
            }
        } else {
            mock.isEnabled = false
            mock.statusCode = OverrideListQueries.defaultResponseStatusCode(for: rowKey, in: endpoints)
            mock.body = nil
            mock.contentType = nil
        }
    }
}

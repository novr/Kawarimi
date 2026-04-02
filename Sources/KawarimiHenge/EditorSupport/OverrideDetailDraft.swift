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

    mutating func resyncMockFromServer(overrides: [MockOverride], endpoints: [any SpecEndpointProviding]) {
        let rowKey = endpointRowKey
        let candidates = overrides.filter { $0.isEnabled && $0.method == rowKey.method && $0.path == rowKey.path }
        if let ov = MockOverride.sortedForInterceptorTieBreak(candidates).first {
            mock.isEnabled = true
            mock.statusCode = ov.statusCode
            mock.exampleId = ov.exampleId
            if let ep = OverrideListQueries.endpoint(for: rowKey, in: endpoints) {
                mergeResponseTemplate(endpoint: ep, overrides: overrides, statusCode: ov.statusCode, into: &mock)
            }
        } else {
            mock.isEnabled = false
            mock.statusCode = OverrideListQueries.defaultResponseStatusCode(for: rowKey, in: endpoints)
            mock.exampleId = nil
            mock.body = nil
            mock.contentType = nil
        }
    }
}

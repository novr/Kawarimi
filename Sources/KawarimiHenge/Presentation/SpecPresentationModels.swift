import KawarimiCore

struct SpecEndpointItem: Identifiable, Sendable {
    let id: String
    let endpoint: any SpecEndpointProviding
    let rowKey: EndpointRowKey

    /// Picker rows for `ForEach`; each row uses ``SpecMockResponseProviding/id`` so duplicate status codes stay distinct.
    var mockResponsePickerItems: [SpecMockResponseItem] {
        endpoint.responseList.map { SpecMockResponseItem(response: $0) }
    }

    init(_ endpoint: any SpecEndpointProviding) {
        id = endpoint.operationId
        self.endpoint = endpoint
        rowKey = EndpointRowKey(endpoint)
    }
}

struct SpecMockResponseItem: Identifiable, Sendable {
    let id: String
    let response: any SpecMockResponseProviding

    init(response: any SpecMockResponseProviding) {
        self.response = response
        id = response.id
    }
}

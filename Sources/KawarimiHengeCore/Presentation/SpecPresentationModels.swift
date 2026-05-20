import KawarimiCore

package struct SpecEndpointItem: Identifiable, Sendable {
    package let id: String
    package let endpoint: any SpecEndpointProviding
    package let rowKey: EndpointRowKey

    /// Picker rows for `ForEach`; each row uses ``SpecMockResponseProviding/id`` so duplicate status codes stay distinct.
    package var mockResponsePickerItems: [SpecMockResponseItem] {
        endpoint.responseList.map { SpecMockResponseItem(response: $0) }
    }

    package init(_ endpoint: any SpecEndpointProviding) {
        id = endpoint.operationId
        self.endpoint = endpoint
        rowKey = EndpointRowKey(endpoint)
    }
}

package struct SpecMockResponseItem: Identifiable, Sendable {
    package let id: String
    package let response: any SpecMockResponseProviding

    package init(response: any SpecMockResponseProviding) {
        self.response = response
        id = response.id
    }
}

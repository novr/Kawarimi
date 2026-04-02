import KawarimiCore

struct SpecEndpointItem: Identifiable, Sendable {
    let id: String
    let endpoint: any SpecEndpointProviding
    let rowKey: EndpointRowKey

    /// Picker rows for `ForEach`; ids mix index and exampleId so duplicate status codes stay distinct.
    var mockResponsePickerItems: [SpecMockResponseItem] {
        endpoint.responseList.enumerated().map { SpecMockResponseItem(response: $0.element, index: $0.offset) }
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

    init(response: any SpecMockResponseProviding, index: Int) {
        self.response = response
        let ex = response.exampleId ?? ""
        if ex.isEmpty {
            id = "status-\(response.statusCode)-i\(index)"
        } else {
            id = "status-\(response.statusCode)-ex-\(ex)"
        }
    }
}

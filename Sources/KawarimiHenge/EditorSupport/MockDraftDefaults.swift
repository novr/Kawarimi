import KawarimiCore

enum MockDraftDefaults {
    static func specPlaceholder(for item: SpecEndpointItem) -> MockOverride {
        let endpoint = item.endpoint
        return MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: endpoint.responseList.first?.statusCode ?? 200,
            exampleId: nil,
            isEnabled: false,
            body: nil,
            contentType: nil
        )
    }
}

import KawarimiCore

enum OverrideSavePayloadBuilder {
    /// Builds the `MockOverride` sent on Save (toggle semantics: off → spec default row, `exampleId` cleared).
    static func build(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        rowKey: EndpointRowKey,
        pathPrefix: String,
        overrides: [MockOverride]
    ) -> MockOverride {
        let hasRow = OverrideListQueries.hasStoredRowMatchingDraft(
            mock,
            rowKey: rowKey,
            operationId: endpoint.operationId,
            pathPrefix: pathPrefix,
            in: overrides
        )
        let isListedInSpec = OverrideListQueries.specContainsResponse(
            endpoint,
            statusCode: mock.statusCode,
            exampleId: mock.exampleId
        )
        let enabled = mock.isEnabled || hasRow || !isListedInSpec
        let trimmed = (mock.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String?
        let contentType: String?
        if !enabled {
            body = nil
            contentType = nil
        } else {
            body = trimmed.isEmpty ? nil : mock.body
            contentType = body == nil ? nil : ((mock.contentType ?? "").isEmpty ? nil : mock.contentType)
        }
        return MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: enabled ? mock.statusCode : (endpoint.responseList.first?.statusCode ?? 200),
            exampleId: enabled ? mock.exampleId : nil,
            isEnabled: enabled,
            body: body,
            contentType: contentType
        )
    }
}

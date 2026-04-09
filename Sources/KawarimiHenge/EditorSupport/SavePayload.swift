import KawarimiCore

enum SavePayload {
    static func build(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        if OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint) {
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
        let enabled = mock.isEnabled
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
        // Disabled saves must target the same override identity as the draft (status + exampleId). Using
        // `responseList.first` here incorrectly rewrote e.g. 201 → 200 when turning off a non-first spec row.
        return MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: mock.statusCode,
            exampleId: mock.exampleId,
            isEnabled: enabled,
            body: body,
            contentType: contentType
        )
    }
}

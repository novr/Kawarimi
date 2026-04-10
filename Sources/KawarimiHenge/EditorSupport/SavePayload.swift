import KawarimiCore

enum SavePayload {
    /// Force **enabled** payload (tests / programmatic); UI uses ``build``.
    static func buildApplyPrimary(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        if OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint) {
            return specOnlyDisablePayload(endpoint: endpoint)
        }
        return enabledRowPayload(mock: mock, endpoint: endpoint)
    }

    /// Force **disabled** payload with body preserved (tests / programmatic); UI uses ``build``.
    static func buildSaveInactive(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        if OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint) {
            return specOnlyDisablePayload(endpoint: endpoint)
        }
        return disabledRowPayload(mock: mock, endpoint: endpoint)
    }

    /// **UI Save**: Spec-only early exit when the user is on **Spec** (not a numbered chip), else **`mock.isEnabled`** — or **`pinnedNumberedResponseChip`** — chooses enabled vs disabled.
    ///
    /// A **stored-off** OpenAPI row still copies the spec template into the draft (`mock.isEnabled == false` but ``OverrideListQueries/draftRepresentsSpecOnlyRowForSave`` is true). If the user tapped a **numbered** chip, `pinnedNumberedResponseChip` is true and Save must **enable** that row, not take the Spec-only disable path.
    static func build(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        pinnedNumberedResponseChip: Bool = false
    ) -> MockOverride {
        if !pinnedNumberedResponseChip,
           OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint) {
            return specOnlyDisablePayload(endpoint: endpoint)
        }
        if mock.isEnabled || pinnedNumberedResponseChip {
            return enabledRowPayload(mock: mock, endpoint: endpoint)
        }
        return disabledRowPayload(mock: mock, endpoint: endpoint)
    }

    private static func specOnlyDisablePayload(endpoint: any SpecEndpointProviding) -> MockOverride {
        MockOverride(
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

    private static func enabledRowPayload(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        let trimmed = (mock.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String? = trimmed.isEmpty ? nil : mock.body
        let contentType: String? = body == nil ? nil : ((mock.contentType ?? "").isEmpty ? nil : mock.contentType)
        return MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: mock.statusCode,
            exampleId: mock.exampleId,
            isEnabled: true,
            body: body,
            contentType: contentType
        )
    }

    private static func disabledRowPayload(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        // Same identity rules as enabled; keep trimmed body / content type so inactive rows persist JSON on the server.
        let trimmed = (mock.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String? = trimmed.isEmpty ? nil : mock.body
        let contentType: String? = body == nil ? nil : ((mock.contentType ?? "").isEmpty ? nil : mock.contentType)
        return MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: mock.statusCode,
            exampleId: mock.exampleId,
            isEnabled: false,
            body: body,
            contentType: contentType
        )
    }
}

import KawarimiCore

enum SavePayload {
    /// Main **Apply** action: persist **Spec-only** disable, or upsert the draft row **enabled** (promote to primary; client disables peers).
    static func buildApplyPrimary(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        if OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint) {
            return specOnlyDisablePayload(endpoint: endpoint)
        }
        return enabledRowPayload(mock: mock, endpoint: endpoint)
    }

    /// **Save inactive**: persist row identity with **`isEnabled: false`** (no primary promotion).
    static func buildSaveInactive(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        if OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint) {
            return specOnlyDisablePayload(endpoint: endpoint)
        }
        return disabledRowPayload(mock: mock, endpoint: endpoint)
    }

    /// Legacy: respects **`mock.isEnabled`** (Mock active). Prefer ``buildApplyPrimary`` / ``buildSaveInactive`` in new UI.
    static func build(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding
    ) -> MockOverride {
        if OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint) {
            return specOnlyDisablePayload(endpoint: endpoint)
        }
        if mock.isEnabled {
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
        // Disabled saves must target the same override identity as the draft (status + exampleId). Using
        // `responseList.first` here incorrectly rewrote e.g. 201 → 200 when turning off a non-first spec row.
        MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: mock.statusCode,
            exampleId: mock.exampleId,
            isEnabled: false,
            body: nil,
            contentType: nil
        )
    }
}

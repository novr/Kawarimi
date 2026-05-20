import KawarimiCore

package enum MockDraftDefaults {
    /// Spec-default mock for an operation (disabled, no body) — shared by ``OverrideEditorStore/buildDetail`` and list/detail bindings.
    package static func specPlaceholder(for endpoint: any SpecEndpointProviding) -> MockOverride {
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

    package static func specPlaceholder(for item: SpecEndpointItem) -> MockOverride {
        specPlaceholder(for: item.endpoint)
    }
}

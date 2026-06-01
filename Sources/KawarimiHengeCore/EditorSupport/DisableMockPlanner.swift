import KawarimiCore

package enum DisableMockPlanner {
    package enum Plan: Equatable {
        case removeThenReset(storedRow: MockOverride, cleared: MockOverride)
        case clearDraftLocally
        case none
    }

    package static func plan(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        rowKey: EndpointRowKey,
        pathPrefix: String,
        overrides: [MockOverride],
        hasUnsavedDraft: Bool
    ) -> Plan {
        if let stored = OverrideListQueries.storedOverrideForDel(
            mock: mock,
            rowKey: rowKey,
            endpoint: endpoint,
            operationId: endpoint.operationId,
            pathPrefix: pathPrefix,
            in: overrides
        ) {
            return .removeThenReset(
                storedRow: stored,
                cleared: clearedDraft(for: endpoint)
            )
        }
        if hasUnsavedDraft {
            return .clearDraftLocally
        }
        return .none
    }

    private static func clearedDraft(for endpoint: any SpecEndpointProviding) -> MockOverride {
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
}

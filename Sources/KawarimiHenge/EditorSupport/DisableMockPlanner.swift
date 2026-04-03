import KawarimiCore

enum DisableMockPlanner {
    enum Plan: Equatable {
        case configureDisable(MockOverride)
        case removeThenReset(removeKey: MockOverride, cleared: MockOverride)
        case none
    }

    static func plan(
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        rowKey: EndpointRowKey,
        pathPrefix: String,
        overrides: [MockOverride]
    ) -> Plan {
        let hasRow = OverrideListQueries.hasStoredRowMatchingDraft(
            mock,
            rowKey: rowKey,
            operationId: endpoint.operationId,
            pathPrefix: pathPrefix,
            in: overrides
        )
        if mock.isEnabled {
            return .configureDisable(
                MockOverride(
                    name: endpoint.operationId,
                    path: endpoint.path,
                    method: endpoint.method,
                    statusCode: mock.statusCode,
                    exampleId: mock.exampleId,
                    isEnabled: false,
                    body: mock.body,
                    contentType: mock.contentType
                )
            )
        }
        if hasRow {
            let removeKey = MockOverride(
                name: endpoint.operationId,
                path: endpoint.path,
                method: endpoint.method,
                statusCode: mock.statusCode,
                exampleId: mock.exampleId,
                isEnabled: false,
                body: nil,
                contentType: nil
            )
            let cleared = MockOverride(
                name: endpoint.operationId,
                path: endpoint.path,
                method: endpoint.method,
                statusCode: endpoint.responseList.first?.statusCode ?? 200,
                exampleId: nil,
                isEnabled: false,
                body: nil,
                contentType: nil
            )
            return .removeThenReset(removeKey: removeKey, cleared: cleared)
        }
        return .none
    }
}

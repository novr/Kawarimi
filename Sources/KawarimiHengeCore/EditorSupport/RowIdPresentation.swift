import KawarimiCore

package enum RowIdPresentation {
    package static func copyText(for rowId: MockOverrideRowID) -> String {
        rowId.rawValue
    }

    package static func displayRowId(
        mock: MockOverride,
        rowKey: EndpointRowKey,
        endpoint: any SpecEndpointProviding,
        operationId: String?,
        pathPrefix: String,
        in overrides: [MockOverride]
    ) -> String? {
        guard let stored = OverrideListQueries.storedOverrideForDel(
            mock: mock,
            rowKey: rowKey,
            endpoint: endpoint,
            operationId: operationId,
            pathPrefix: pathPrefix,
            in: overrides
        ) else { return nil }
        guard let rowId = stored.rowId else { return nil }
        return copyText(for: rowId)
    }
}

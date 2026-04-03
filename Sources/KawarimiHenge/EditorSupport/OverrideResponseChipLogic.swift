import KawarimiCore

struct MockResponseStatusChipOption: Identifiable {
    static let specRowId = "spec"

    let id: String
    let statusCode: Int
    let exampleId: String?
    let label: String
    let isInactive: Bool

    var isSpec: Bool { id == Self.specRowId }
}

enum OverrideResponseChipLogic {
    /// Picker source for “Add response”; rows are distinguished by `exampleId`, so duplicate HTTP statuses are allowed.
    static let commonCustomHTTPStatusCodes: [Int] = [
        100, 101, 103,
        200, 201, 202, 203, 204, 205, 206, 207, 208, 226,
        300, 301, 302, 303, 304, 307, 308,
        400, 401, 402, 403, 404, 405, 406, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 421, 422, 423, 424, 425, 426, 428, 429, 431, 451,
        500, 501, 502, 503, 504, 505, 506, 507, 508, 510, 511,
    ]

    static func supplementalRowChipId(statusCode: Int, exampleId: String?) -> String {
        let ex = MockExamplePresentation.normalizedExampleId(exampleId).map { $0 } ?? "_default"
        return "supplemental:\(statusCode):\(ex)"
    }

    static func supplementalChipLabel(statusCode: Int, exampleId: String?) -> String {
        if let ex = MockExamplePresentation.normalizedExampleId(exampleId) {
            return "\(statusCode) · \(ex)"
        }
        return "\(statusCode) \(OverrideEditorHTTPStatus.phrase(for: statusCode))"
    }

    static func buildChipOptions(
        mock: MockOverride,
        endpointItem: SpecEndpointItem,
        endpoint: any SpecEndpointProviding,
        overrides: [MockOverride],
        pathPrefix: String
    ) -> [MockResponseStatusChipOption] {
        var out: [MockResponseStatusChipOption] = [
            MockResponseStatusChipOption(
                id: MockResponseStatusChipOption.specRowId,
                statusCode: -1,
                exampleId: nil,
                label: "Spec",
                isInactive: false
            ),
        ]
        for item in endpointItem.mockResponsePickerItems {
            let r = item.response
            let c = r.statusCode
            let exLabel = MockExamplePresentation.label(for: r)
            let label: String
            if MockExamplePresentation.normalizedExampleId(r.exampleId) != nil {
                label = "\(c) · \(exLabel)"
            } else {
                label = "\(c) \(OverrideEditorHTTPStatus.phrase(for: c))"
            }
            out.append(
                MockResponseStatusChipOption(id: item.id, statusCode: c, exampleId: r.exampleId, label: label, isInactive: false)
            )
        }
        let customs = OverrideListQueries.customOverrides(
            for: endpointItem.rowKey,
            endpoint: endpoint,
            operationId: endpoint.operationId,
            pathPrefix: pathPrefix,
            in: overrides
        )
        let sortedCustoms = MockOverride.sortedForInterceptorTieBreak(customs)
        for ov in sortedCustoms {
            let id = supplementalRowChipId(statusCode: ov.statusCode, exampleId: ov.exampleId)
            let label = supplementalChipLabel(statusCode: ov.statusCode, exampleId: ov.exampleId)
            out.append(
                MockResponseStatusChipOption(
                    id: id,
                    statusCode: ov.statusCode,
                    exampleId: ov.exampleId,
                    label: label,
                    isInactive: !ov.isEnabled
                )
            )
        }
        if mock.isEnabled,
           !OverrideListQueries.specContainsResponse(endpoint, statusCode: mock.statusCode, exampleId: mock.exampleId)
        {
            let draftId = supplementalRowChipId(statusCode: mock.statusCode, exampleId: mock.exampleId)
            let alreadyListed = out.contains { opt in
                !opt.isSpec && opt.statusCode == mock.statusCode
                    && MockExamplePresentation.exampleIdsEqual(opt.exampleId, mock.exampleId)
            }
            if !alreadyListed {
                let label = supplementalChipLabel(statusCode: mock.statusCode, exampleId: mock.exampleId)
                out.append(
                    MockResponseStatusChipOption(
                        id: draftId,
                        statusCode: mock.statusCode,
                        exampleId: mock.exampleId,
                        label: label,
                        isInactive: false
                    )
                )
            }
        }
        return out
    }

    static func responseOptionExists(
        statusCode: Int,
        exampleId: String?,
        options: [MockResponseStatusChipOption]
    ) -> Bool {
        options.contains { opt in
            !opt.isSpec && opt.statusCode == statusCode && MockExamplePresentation.exampleIdsEqual(opt.exampleId, exampleId)
        }
    }

    static func chipIsSelected(
        option: MockResponseStatusChipOption,
        mock: MockOverride,
        rowKey: EndpointRowKey,
        operationId: String,
        pathPrefix: String,
        overrides: [MockOverride]
    ) -> Bool {
        if option.isSpec {
            if mock.isEnabled { return false }
            return !OverrideListQueries.hasStoredRowMatchingDraft(
                mock,
                rowKey: rowKey,
                operationId: operationId,
                pathPrefix: pathPrefix,
                in: overrides
            )
        }
        return mock.statusCode == option.statusCode
            && MockExamplePresentation.exampleIdsEqual(mock.exampleId, option.exampleId)
    }

    static func applyChipSelection(
        option: MockResponseStatusChipOption,
        mock: inout MockOverride,
        endpointItem: SpecEndpointItem,
        endpoint: any SpecEndpointProviding,
        overrides: [MockOverride],
        pathPrefix: String
    ) {
        if option.isSpec {
            mock.isEnabled = false
            mock.statusCode = endpoint.responseList.first?.statusCode ?? 200
            mock.exampleId = nil
            mock.body = nil
            mock.contentType = nil
        } else if let stored = OverrideListQueries.storedOverride(
            for: endpointItem.rowKey,
            operationId: endpoint.operationId,
            pathPrefix: pathPrefix,
            statusCode: option.statusCode,
            exampleId: option.exampleId,
            in: overrides
        ) {
            mock.isEnabled = stored.isEnabled
            mock.statusCode = stored.statusCode
            mock.exampleId = stored.exampleId
            mock.name = stored.name ?? endpoint.operationId
            if stored.hasEffectiveCustomBody {
                mock.body = stored.body
                mock.contentType = stored.contentType
            } else {
                mergeResponseTemplate(
                    endpoint: endpoint,
                    overrides: overrides,
                    pathPrefix: pathPrefix,
                    statusCode: option.statusCode,
                    into: &mock
                )
            }
        } else {
            mock.isEnabled = true
            mock.statusCode = option.statusCode
            mock.exampleId = option.exampleId
            mergeResponseTemplate(
                endpoint: endpoint,
                overrides: overrides,
                pathPrefix: pathPrefix,
                statusCode: option.statusCode,
                into: &mock
            )
        }
    }
}

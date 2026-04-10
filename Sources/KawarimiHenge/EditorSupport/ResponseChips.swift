import KawarimiCore

struct ResponseChip: Identifiable {
    static let specRowId = "spec"

    let id: String
    let statusCode: Int
    let exampleId: String?
    let label: String
    let isInactive: Bool
    /// Index into ``SpecEndpointProviding/responseList`` for chips built from the spec picker; disambiguates duplicate status + example rows.
    let specResponseListIndex: Int?

    var isSpec: Bool { id == Self.specRowId }

    init(
        id: String,
        statusCode: Int,
        exampleId: String?,
        label: String,
        isInactive: Bool,
        specResponseListIndex: Int? = nil
    ) {
        self.id = id
        self.statusCode = statusCode
        self.exampleId = exampleId
        self.label = label
        self.isInactive = isInactive
        self.specResponseListIndex = specResponseListIndex
    }
}

enum ResponseChips {
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
        return "\(statusCode) \(HTTPStatusPhrase.text(for: statusCode))"
    }

    static func buildChipOptions(
        mock: MockOverride,
        endpointItem: SpecEndpointItem,
        endpoint: any SpecEndpointProviding,
        overrides: [MockOverride],
        pathPrefix: String
    ) -> [ResponseChip] {
        var out: [ResponseChip] = [
            ResponseChip(
                id: ResponseChip.specRowId,
                statusCode: -1,
                exampleId: nil,
                label: "Spec",
                isInactive: false,
                specResponseListIndex: nil
            ),
        ]
        for (idx, item) in endpointItem.mockResponsePickerItems.enumerated() {
            let r = item.response
            let c = r.statusCode
            let exLabel = MockExamplePresentation.label(for: r)
            let label: String
            if MockExamplePresentation.normalizedExampleId(r.exampleId) != nil {
                label = "\(c) · \(exLabel)"
            } else {
                label = "\(c) \(HTTPStatusPhrase.text(for: c))"
            }
            // Stable unique `id` per row — `SpecMockResponseProviding.id` can collide for multiple defaults on the same status.
            out.append(
                ResponseChip(
                    id: "spec:\(idx)",
                    statusCode: c,
                    exampleId: r.exampleId,
                    label: label,
                    isInactive: false,
                    specResponseListIndex: idx
                )
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
                ResponseChip(
                    id: id,
                    statusCode: ov.statusCode,
                    exampleId: ov.exampleId,
                    label: label,
                    isInactive: !ov.isEnabled,
                    specResponseListIndex: nil
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
                    ResponseChip(
                        id: draftId,
                        statusCode: mock.statusCode,
                        exampleId: mock.exampleId,
                        label: label,
                        isInactive: false,
                        specResponseListIndex: nil
                    )
                )
            }
        }
        return out
    }

    static func responseOptionExists(
        statusCode: Int,
        exampleId: String?,
        options: [ResponseChip]
    ) -> Bool {
        options.contains { opt in
            !opt.isSpec && opt.statusCode == statusCode && MockExamplePresentation.exampleIdsEqual(opt.exampleId, exampleId)
        }
    }

    static func chipIsSelected(
        option: ResponseChip,
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        pinnedNumberedResponseChip: Bool = false
    ) -> Bool {
        if mock.isEnabled {
            if option.isSpec { return false }
            return numberedChipMatchesMock(option, mock)
        }
        let specSelected = !pinnedNumberedResponseChip
            && OverrideListQueries.draftRepresentsSpecOnlyRowForSave(mock: mock, endpoint: endpoint)
        if option.isSpec { return specSelected }
        guard numberedChipMatchesMock(option, mock) else { return false }
        return !specSelected
    }

    private static func numberedChipMatchesMock(_ option: ResponseChip, _ mock: MockOverride) -> Bool {
        mock.statusCode == option.statusCode
            && MockExamplePresentation.exampleIdsEqual(mock.exampleId, option.exampleId)
    }

    static func applyChipSelection(
        option: ResponseChip,
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

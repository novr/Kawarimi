import KawarimiCore

package struct ResponseDocumentation: Sendable {
    package let summary: String?
    package let description: String?

    package var hasContent: Bool {
        !(summary ?? "").isEmpty || !(description ?? "").isEmpty
    }
}

package enum ResponsePresentation {
    package static func selectedChip(
        options: [ResponseChip],
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        pinnedNumberedResponseChip: Bool
    ) -> ResponseChip? {
        options.first { chip in
            ResponseChips.chipIsSelected(
                option: chip,
                mock: mock,
                endpoint: endpoint,
                pinnedNumberedResponseChip: pinnedNumberedResponseChip
            )
        }
    }

    package static func specResponse(
        for chip: ResponseChip,
        endpoint: any SpecEndpointProviding
    ) -> (any SpecMockResponseProviding)? {
        guard !chip.isSpec else { return nil }
        let list = endpoint.responseList
        if let idx = chip.specResponseListIndex, list.indices.contains(idx) {
            return list[idx]
        }
        return list.first { response in
            response.statusCode == chip.statusCode
                && MockExamplePresentation.exampleIdsEqual(response.exampleId, chip.exampleId)
        }
    }

    package static func specResponseForSelection(
        options: [ResponseChip],
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        pinnedNumberedResponseChip: Bool
    ) -> (any SpecMockResponseProviding)? {
        guard let chip = selectedChip(
            options: options,
            mock: mock,
            endpoint: endpoint,
            pinnedNumberedResponseChip: pinnedNumberedResponseChip
        ) else { return nil }
        return specResponse(for: chip, endpoint: endpoint)
    }

    package static func documentation(for response: any SpecMockResponseProviding) -> ResponseDocumentation {
        func trimmed(_ text: String?) -> String? {
            guard let text else { return nil }
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        return ResponseDocumentation(
            summary: trimmed(response.summary),
            description: trimmed(response.description)
        )
    }

    package static func documentationForSelection(
        options: [ResponseChip],
        mock: MockOverride,
        endpoint: any SpecEndpointProviding,
        pinnedNumberedResponseChip: Bool
    ) -> ResponseDocumentation? {
        guard let response = specResponseForSelection(
            options: options,
            mock: mock,
            endpoint: endpoint,
            pinnedNumberedResponseChip: pinnedNumberedResponseChip
        ) else { return nil }
        let doc = documentation(for: response)
        return doc.hasContent ? doc : nil
    }
}

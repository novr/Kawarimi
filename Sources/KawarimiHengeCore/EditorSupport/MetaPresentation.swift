import KawarimiCore

package enum MetaPresentation {
    package static func apiDescription(for meta: any SpecMetaProviding) -> String? {
        guard let description = meta.description else { return nil }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

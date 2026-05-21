import KawarimiCore

package enum TagsPresentation {
    /// OpenAPI operation `tags` when present; `nil` when absent or empty.
    package static func displayTags(for endpoint: any SpecEndpointProviding) -> [String]? {
        guard let tags = endpoint.tags, !tags.isEmpty else { return nil }
        return tags
    }
}

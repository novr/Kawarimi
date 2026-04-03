import KawarimiCore

enum OverrideEndpointFilter {
    static func filter(_ items: [SpecEndpointItem], searchText: String) -> [SpecEndpointItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        let lower = q.lowercased()
        return items.filter { item in
            let ep = item.endpoint
            if ep.path.lowercased().contains(lower) { return true }
            if ep.method.rawValue.lowercased().contains(lower) { return true }
            if ep.operationId.lowercased().contains(lower) { return true }
            return false
        }
    }
}

import Foundation

/// In-memory ring buffer of recorded requests for the Spy admin API.
public actor KawarimiRequestHistoryStore {
    private var entries: [RecordedRequest] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 500) {
        self.maxEntries = max(1, maxEntries)
    }

    public func record(_ request: RecordedRequest) {
        entries.append(request)
        let overflow = entries.count - maxEntries
        if overflow > 0 {
            entries.removeFirst(overflow)
        }
    }

    /// Returns entries in record order (oldest first). Multiple filters are AND-ed.
    public func requests(
        operationId: String? = nil,
        path: String? = nil,
        method: String? = nil
    ) -> [RecordedRequest] {
        entries.filter { entry in
            if let operationId, entry.matchedOperationId != operationId {
                return false
            }
            if let path, entry.path != path {
                return false
            }
            if let method, entry.method.lowercased() != method.lowercased() {
                return false
            }
            return true
        }
    }

    public func clear() {
        entries.removeAll()
    }
}

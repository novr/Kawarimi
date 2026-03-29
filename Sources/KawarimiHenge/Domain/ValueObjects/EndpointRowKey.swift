import KawarimiCore

/// Aligns list selection tags with server matching on path and method (not `operationId`, which is OpenAPI-specific).
struct EndpointRowKey: Hashable, Sendable {
    var method: String
    var path: String

    init(method: String, path: String) {
        self.method = method
        self.path = path
    }

    init(_ endpoint: any SpecEndpointProviding) {
        method = endpoint.method
        path = endpoint.path
    }
}

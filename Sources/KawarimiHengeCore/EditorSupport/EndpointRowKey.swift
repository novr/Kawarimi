import Foundation
import HTTPTypes
import KawarimiCore

/// Aligns list selection tags with server matching on path and method (not `operationId`, which is OpenAPI-specific).
package struct EndpointRowKey: Hashable, Sendable {
    package var method: HTTPRequest.Method
    package var path: String

    package init(method: HTTPRequest.Method, path: String) {
        self.method = method
        self.path = path
    }

    package init(_ endpoint: any SpecEndpointProviding) {
        method = endpoint.method
        path = endpoint.path
    }
}

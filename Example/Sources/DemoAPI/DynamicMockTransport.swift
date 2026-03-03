import Foundation
import HTTPTypes
import OpenAPIRuntime

public struct DynamicMockTransport: ClientTransport {
    private let underlying: any ClientTransport
    private let realBaseURL: URL
    private let mockBaseURL: URL
    public var useMockServer: Bool
    public var mockId: String?

    public init(
        underlying: any ClientTransport,
        realBaseURL: URL,
        mockBaseURL: URL,
        useMockServer: Bool = false
    ) {
        self.underlying = underlying
        self.realBaseURL = realBaseURL
        self.mockBaseURL = mockBaseURL
        self.useMockServer = useMockServer
        self.mockId = nil
    }

    public func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let effectiveBaseURL = useMockServer ? mockBaseURL : realBaseURL
        var effectiveRequest = request
        if useMockServer, let mockId, let name = HTTPField.Name("x-kawarimi-mockId") {
            effectiveRequest.headerFields[name] = mockId
        }
        return try await underlying.send(
            effectiveRequest,
            body: body,
            baseURL: effectiveBaseURL,
            operationID: operationID
        )
    }
}

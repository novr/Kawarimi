import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiServer

@Suite("KawarimiProxyResponseBodyPolicy")
struct KawarimiProxyResponseBodyPolicyTests {
    @Test func declaredLengthPrefersContentLengthHeader() throws {
        let limit = KawarimiProxyForwardLimits.maxResponseBodyBytes
        let url = try #require(URL(string: "http://127.0.0.1/"))
        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Length": "\(limit + 1)"]
            )
        )
        let declared = try #require(KawarimiProxyResponseBodyPolicy.declaredBodyLength(response))
        #expect(declared == limit + 1)
        #expect(declared > limit)
    }
}

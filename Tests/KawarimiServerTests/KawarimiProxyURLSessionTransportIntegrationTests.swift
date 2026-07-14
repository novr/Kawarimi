#if os(macOS)
import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiServer

/// Live URLSession + loopback HTTP. Linux CI uses mock transport tests instead (see KawarimiUpstreamHTTPForwarderTests).
@Suite(.serialized, .timeLimit(.minutes(1)))
struct KawarimiProxyURLSessionTransportIntegrationTests {
    @Test(.timeLimit(.minutes(1))) func liveTransportStreamsGETThroughDelegatePath() async throws {
        let server = try LoopbackHTTPServer.start()
        defer { server.stop() }
        let expected = Data("{\"live\":true}".utf8)
        server.run { request in
            #expect(request.method == "GET")
            #expect(request.path == "/echo")
            return LoopbackHTTPResponse(
                status: 200,
                headers: ["Content-Type": "application/json"],
                body: expected
            )
        }
        try await server.waitUntilAccepting()

        let forwarder = KawarimiUpstreamHTTPForwarder(upstreamOrigin: server.origin)
        let request = HTTPRequest(method: .get, scheme: "http", authority: "127.0.0.1", path: "/echo")
        let (response, body) = try await forwarder.forward(request: request, body: nil, pathPrefix: "")
        #expect(response.status.code == 200)
        let collected = try await Data(collecting: body!, upTo: 4096)
        #expect(collected == expected)
    }

    @Test(.timeLimit(.minutes(1))) func liveTransportStreamsPOSTRequestAndResponse() async throws {
        let server = try LoopbackHTTPServer.start()
        defer { server.stop() }
        let expectedRequest = Data("{\"name\":\"loopback\"}".utf8)
        let expectedResponse = Data("{\"created\":true}".utf8)
        server.run { request in
            #expect(request.method == "POST")
            #expect(request.path == "/items")
            #expect(request.body == expectedRequest)
            return LoopbackHTTPResponse(
                status: 201,
                headers: ["Content-Type": "application/json"],
                body: expectedResponse
            )
        }
        try await server.waitUntilAccepting()

        let forwarder = KawarimiUpstreamHTTPForwarder(upstreamOrigin: server.origin)
        let request = HTTPRequest(method: .post, scheme: "http", authority: "127.0.0.1", path: "/items")
        let (response, body) = try await forwarder.forward(
            request: request,
            body: HTTPBody(expectedRequest),
            pathPrefix: ""
        )
        #expect(response.status.code == 201)
        let collected = try await Data(collecting: body!, upTo: 4096)
        #expect(collected == expectedResponse)
    }

    @Test(.timeLimit(.minutes(1))) func liveTransportHandlesEmptyResponseBody() async throws {
        let server = try LoopbackHTTPServer.start()
        defer { server.stop() }
        server.run { request in
            #expect(request.method == "GET")
            return LoopbackHTTPResponse(status: 204)
        }
        try await server.waitUntilAccepting()

        let forwarder = KawarimiUpstreamHTTPForwarder(upstreamOrigin: server.origin)
        let request = HTTPRequest(method: .get, scheme: "http", authority: "127.0.0.1", path: "/empty")
        let (response, body) = try await forwarder.forward(request: request, body: nil, pathPrefix: "")
        #expect(response.status.code == 204)
        if let body {
            let collected = try await Data(collecting: body, upTo: 1024)
            #expect(collected.isEmpty)
        }
    }

    @Test(.timeLimit(.minutes(1))) func liveTransportOmitsBodyForHEAD() async throws {
        let server = try LoopbackHTTPServer.start()
        defer { server.stop() }
        server.run { request in
            #expect(request.method == "HEAD")
            return LoopbackHTTPResponse(
                status: 200,
                headers: [
                    "Content-Type": "application/json",
                    "Content-Length": "13",
                ],
                body: Data("{\"ignored\":1}".utf8)
            )
        }
        try await server.waitUntilAccepting()

        let forwarder = KawarimiUpstreamHTTPForwarder(upstreamOrigin: server.origin)
        let request = HTTPRequest(method: .head, scheme: "http", authority: "127.0.0.1", path: "/resource")
        let (response, body) = try await forwarder.forward(request: request, body: nil, pathPrefix: "")
        #expect(response.status.code == 200)
        #expect(body == nil)
    }
}
#endif

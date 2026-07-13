import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiServer

@Suite("KawarimiUpstreamHTTPForwarder")
struct KawarimiUpstreamHTTPForwarderTests {
    @Test func buildTargetURLAlignsPathPrefix() throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        var request = HTTPRequest(method: .get, scheme: "http", authority: "127.0.0.1", path: "/greet")
        let url = try #require(
            KawarimiUpstreamHTTPForwarder.buildTargetURL(
                request: request,
                upstreamOrigin: origin,
                pathPrefix: "/api"
            )
        )
        #expect(url.absoluteString == "https://upstream.test/api/greet")

        request.path = "/api/greet?name=x"
        let withQuery = try #require(
            KawarimiUpstreamHTTPForwarder.buildTargetURL(
                request: request,
                upstreamOrigin: origin,
                pathPrefix: "/api"
            )
        )
        #expect(withQuery.absoluteString == "https://upstream.test/api/greet?name=x")
    }

    @Test func forwardStripsKawarimiControlHeadersFromRequest() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        final class Capture: @unchecked Sendable {
            var request: URLRequest?
        }
        let capture = Capture()
        let forwarder = KawarimiUpstreamHTTPForwarder(
            upstreamOrigin: origin,
            transport: .mock { request, _ in
                capture.request = request
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, HTTPBody("{\"ok\":true}"))
            }
        )

        var httpRequest = HTTPRequest(
            method: .get,
            scheme: "http",
            authority: "127.0.0.1",
            path: "/api/widgets"
        )
        httpRequest.headerFields[HTTPField.Name(KawarimiMockRequestHeaders.exampleId)!] = "success"
        httpRequest.headerFields[HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!] = "step-1"
        httpRequest.headerFields[HTTPField.Name("Authorization")!] = "Bearer abc"

        let (response, body) = try await forwarder.forward(
            request: httpRequest,
            body: nil,
            pathPrefix: "/api"
        )
        #expect(response.status.code == 200)
        let collected = try await String(collecting: body!, upTo: 1024)
        #expect(collected == "{\"ok\":true}")

        let forwarded = try #require(capture.request)
        #expect(forwarded.url?.absoluteString == "https://upstream.test/api/widgets")
        #expect(forwarded.value(forHTTPHeaderField: KawarimiMockRequestHeaders.exampleId) == nil)
        #expect(forwarded.value(forHTTPHeaderField: KawarimiScenarioHeaders.kawarimiId) == nil)
        #expect(forwarded.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    @Test func forwardOmitsContentLengthWhenBodyPresent() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        final class Capture: @unchecked Sendable {
            var request: URLRequest?
            var body: HTTPBody?
        }
        let capture = Capture()
        let forwarder = KawarimiUpstreamHTTPForwarder(
            upstreamOrigin: origin,
            transport: .mock { request, body in
                capture.request = request
                capture.body = body
                let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
                return (response, nil)
            }
        )

        var httpRequest = HTTPRequest(method: .post, scheme: "http", authority: "127.0.0.1", path: "/api/items")
        httpRequest.headerFields[HTTPField.Name("Content-Length")!] = "99"
        let payload = HTTPBody("{\"name\":\"Proxy POST\"}")
        _ = try await forwarder.forward(request: httpRequest, body: payload, pathPrefix: "/api")

        let forwarded = try #require(capture.request)
        #expect(forwarded.value(forHTTPHeaderField: "Content-Length") == nil)
        let forwardedBody = try #require(capture.body)
        let collected = try await String(collecting: forwardedBody, upTo: 1024)
        #expect(collected == "{\"name\":\"Proxy POST\"}")
    }

    @Test func forwardStripsKawarimiControlHeadersFromUpstreamResponse() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        let forwarder = KawarimiUpstreamHTTPForwarder(
            upstreamOrigin: origin,
            transport: .mock { request, _ in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Type": "application/json",
                        KawarimiScenarioHeaders.nextKawarimiId: "step-2",
                        KawarimiProxyHeaders.proxyAction: KawarimiProxyHeaders.actionMock,
                    ]
                )!
                return (response, HTTPBody("{\"ok\":true}"))
            }
        )

        let request = HTTPRequest(method: .get, scheme: "http", authority: "127.0.0.1", path: "/api/widgets")
        let (response, _) = try await forwarder.forward(request: request, body: nil, pathPrefix: "/api")
        #expect(response.headerFields[HTTPField.Name("Content-Type")!] == "application/json")
        #expect(response.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] == nil)
        #expect(response.headerFields[HTTPField.Name(KawarimiProxyHeaders.proxyAction)!] == nil)
    }

    @Test func forwardReturns413WhenBodyExceedsLimit() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        let limit = KawarimiProxyForwardLimits.maxRequestBodyBytes
        let forwarder = KawarimiUpstreamHTTPForwarder(
            upstreamOrigin: origin,
            transport: .mock { _, _ in
                throw KawarimiProxyForwardError.bodyTooLarge(limit: limit)
            }
        )
        let request = HTTPRequest(method: .post, scheme: "http", authority: "127.0.0.1", path: "/api/items")
        let (response, body) = try await forwarder.forward(
            request: request,
            body: HTTPBody("payload"),
            pathPrefix: "/api"
        )
        #expect(response.status.code == 413)
        let text = try await String(collecting: body!, upTo: 256)
        #expect(text.contains("\(limit)"))
    }

    @Test func forwardReturns502WhenResponseBodyExceedsLimit() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        let limit = KawarimiProxyForwardLimits.maxResponseBodyBytes
        let forwarder = KawarimiUpstreamHTTPForwarder(
            upstreamOrigin: origin,
            transport: .mock { _, _ in
                throw KawarimiProxyForwardError.responseTooLarge(limit: limit)
            }
        )
        let request = HTTPRequest(method: .get, scheme: "http", authority: "127.0.0.1", path: "/api/large")
        let (response, body) = try await forwarder.forward(request: request, body: nil, pathPrefix: "/api")
        #expect(response.status.code == 502)
        let text = try await String(collecting: body!, upTo: 256)
        #expect(text.contains("\(limit)"))
    }

    @Test func forwardReturns502WhenUpstreamFails() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        let forwarder = KawarimiUpstreamHTTPForwarder(
            upstreamOrigin: origin,
            transport: .mock { _, _ in
                throw URLError(.cannotConnectToHost)
            }
        )
        let request = HTTPRequest(method: .get, scheme: "http", authority: "127.0.0.1", path: "/api/greet")
        let (response, body) = try await forwarder.forward(request: request, body: nil, pathPrefix: "/api")
        #expect(response.status.code == 502)
        let text = try await String(collecting: body!, upTo: 256)
        #expect(text == "Upstream unreachable")
    }
}

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
        let forwarder = KawarimiUpstreamHTTPForwarder(upstreamOrigin: origin) { request, _ in
            capture.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, HTTPBody("{\"ok\":true}"))
        }

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

    @Test func forwardPassesRequestBodyWithoutCollectingInForwarder() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        final class Capture: @unchecked Sendable {
            var request: URLRequest?
            var body: HTTPBody?
        }
        let capture = Capture()
        let forwarder = KawarimiUpstreamHTTPForwarder(upstreamOrigin: origin) { request, body in
            capture.request = request
            capture.body = body
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        let request = HTTPRequest(method: .post, scheme: "http", authority: "127.0.0.1", path: "/api/items")
        let payload = HTTPBody("{\"name\":\"Proxy POST\"}")
        let (response, _) = try await forwarder.forward(request: request, body: payload, pathPrefix: "/api")
        #expect(response.status.code == 201)

        let forwardedBody = try #require(capture.body)
        let collected = try await String(collecting: forwardedBody, upTo: 1024)
        #expect(collected == "{\"name\":\"Proxy POST\"}")
    }

    @Test func forwardReturns502WhenUpstreamFails() async throws {
        let origin = try #require(URL(string: "https://upstream.test"))
        let forwarder = KawarimiUpstreamHTTPForwarder(upstreamOrigin: origin) { _, _ in
            throw URLError(.cannotConnectToHost)
        }
        let request = HTTPRequest(method: .get, scheme: "http", authority: "127.0.0.1", path: "/api/greet")
        let (response, body) = try await forwarder.forward(request: request, body: nil, pathPrefix: "/api")
        #expect(response.status.code == 502)
        let text = try await String(collecting: body!, upTo: 256)
        #expect(text == "Upstream unreachable")
    }
}

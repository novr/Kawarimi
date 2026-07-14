#if os(macOS) || os(Linux)
import Foundation
import KawarimiCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing

@Suite(.serialized, .timeLimit(.minutes(3)))
final class DemoServerE2EProxyTests {
    @Test(.timeLimit(.minutes(3))) func forwardsGreetToUpstreamWhenConfigured() async throws {
        let root = resolveDemoPackageRoot()
        let upstream = try await DemoServerHarness.start(packageRoot: root)
        defer { upstream.shutdown() }

        let proxy = try await DemoServerHarness.start(
            packageRoot: root,
            extraEnvironment: ["KAWARIMI_UPSTREAM_URL": upstream.listenOrigin.absoluteString]
        )
        defer { proxy.shutdown() }

        try await proxy.resetOverrides()
        let (response, data) = try await DemoServerHTTP.get(proxy.baseURL.appending(path: "greet"))
        #expect(response.statusCode == 200)
        #expect(
            response.value(forHTTPHeaderField: KawarimiProxyHeaders.proxyAction)
                == KawarimiProxyHeaders.actionForward
        )
        let body = try DemoServerE2EJSON.decodeGreeting(from: data)
        #expect(body.message == "Hello from API")
    }

    @Test(.timeLimit(.minutes(3))) func overrideOnProxyTakesPriorityOverUpstream() async throws {
        let root = resolveDemoPackageRoot()
        let upstream = try await DemoServerHarness.start(packageRoot: root)
        defer { upstream.shutdown() }

        let proxy = try await DemoServerHarness.start(
            packageRoot: root,
            extraEnvironment: ["KAWARIMI_UPSTREAM_URL": upstream.listenOrigin.absoluteString]
        )
        defer { proxy.shutdown() }

        try await proxy.resetOverrides()
        let greetPath = DemoServerE2EPaths.greetPath
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,\
            "body":"{\\"message\\":\\"Proxy mock wins\\"}","contentType":"application/json"}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            proxy.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let (response, data) = try await DemoServerHTTP.get(proxy.baseURL.appending(path: "greet"))
        #expect(response.statusCode == 200)
        #expect(
            response.value(forHTTPHeaderField: KawarimiProxyHeaders.proxyAction)
                == KawarimiProxyHeaders.actionMock
        )
        let body = try DemoServerE2EJSON.decodeGreeting(from: data)
        #expect(body.message == "Proxy mock wins")
    }

    @Test(.timeLimit(.minutes(3))) func postForwardsToUpstreamWhenConfigured() async throws {
        let root = resolveDemoPackageRoot()
        let upstream = try await DemoServerHarness.start(packageRoot: root)
        defer { upstream.shutdown() }

        let proxy = try await DemoServerHarness.start(
            packageRoot: root,
            extraEnvironment: ["KAWARIMI_UPSTREAM_URL": upstream.listenOrigin.absoluteString]
        )
        defer { proxy.shutdown() }

        try await proxy.resetOverrides()
        let payload = Data("{\"name\":\"Proxy POST\"}".utf8)
        let (response, _) = try await DemoServerHTTP.post(
            proxy.baseURL.appending(path: "items"),
            body: payload,
            contentType: "application/json"
        )
        #expect(response.statusCode == 201)
        #expect(
            response.value(forHTTPHeaderField: KawarimiProxyHeaders.proxyAction)
                == KawarimiProxyHeaders.actionForward
        )
    }

    @Test(.timeLimit(.minutes(3))) func adminRoutesStayLocalWhenUpstreamConfigured() async throws {
        let root = resolveDemoPackageRoot()
        let upstream = try await DemoServerHarness.start(packageRoot: root)
        defer { upstream.shutdown() }

        let proxy = try await DemoServerHarness.start(
            packageRoot: root,
            extraEnvironment: ["KAWARIMI_UPSTREAM_URL": upstream.listenOrigin.absoluteString]
        )
        defer { proxy.shutdown() }

        let (response, data) = try await DemoServerHTTP.get(
            proxy.kawarimiBaseURL.appending(path: KawarimiAdminRoute.spec.relativePath)
        )
        #expect(response.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(response))
        _ = try DemoServerE2EJSON.decodeHengeSpec(from: data)
        #expect(response.value(forHTTPHeaderField: KawarimiProxyHeaders.proxyAction) == nil)
    }
}
#endif

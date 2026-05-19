#if os(macOS) || os(Linux)
import Foundation
import Testing

@Suite(.serialized)
final class DemoServerE2ETests {
    private let server: DemoServerHarness

    init() async throws {
        server = try await DemoServerHarness.start(packageRoot: resolveDemoPackageRoot())
    }

    deinit {
        server.shutdown()
    }

    @Test func greetingReturnsOpenAPIExampleByDefault() async throws {
        try await server.resetOverrides()

        let (response, data) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(response.statusCode == 200)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["message"] as? String == "Hello from API")
    }

    @Test func hengeConfigureAppliesInterceptorOverride() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,\
            "body":"{\\"message\\":\\"From E2E test\\"}","contentType":"application/json"}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let greetJSON = try JSONSerialization.jsonObject(with: greetData) as? [String: Any]
        #expect(greetJSON?["message"] as? String == "From E2E test")

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: "status")
        )
        #expect(statusResponse.statusCode == 200)
        let overrides = try JSONSerialization.jsonObject(with: statusData) as? [[String: Any]]
        #expect(overrides?.count == 1)
        #expect(overrides?.first?["path"] as? String == greetPath)
    }

    @Test func hengeResetClearsOverrides() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,\
            "body":"{\\"message\\":\\"Temporary\\"}","contentType":"application/json"}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        try await server.resetOverrides()

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let greetJSON = try JSONSerialization.jsonObject(with: greetData) as? [String: Any]
        #expect(greetJSON?["message"] as? String == "Hello from API")

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: "status")
        )
        #expect(statusResponse.statusCode == 200)
        let overrides = try JSONSerialization.jsonObject(with: statusData) as? [[String: Any]]
        #expect(overrides?.isEmpty == true)
    }

    @Test func hengeRemoveDeletesOverrideRow() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let row = """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":false}
            """
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: Data(row.utf8)
        )
        #expect(configureResponse.statusCode == 200)

        let (removeResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "remove"),
            body: Data(row.utf8)
        )
        #expect(removeResponse.statusCode == 200)

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: "status")
        )
        #expect(statusResponse.statusCode == 200)
        let overrides = try JSONSerialization.jsonObject(with: statusData) as? [[String: Any]]
        #expect(overrides?.isEmpty == true)
    }
}
#endif

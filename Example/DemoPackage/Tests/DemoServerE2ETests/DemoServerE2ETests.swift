#if os(macOS) || os(Linux)
import Foundation
import KawarimiCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(response))
        let body = try DemoServerE2EJSON.decodeGreeting(from: data)
        #expect(body.message == "Hello from API")
    }

    @Test func hengeConfigureAppliesMiddlewareOverride() async throws {
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
        let greetJSON = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(greetJSON.message == "From E2E test")

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: "status")
        )
        #expect(statusResponse.statusCode == 200)
        let overrides = try DemoServerE2EJSON.decodeOverrides(from: statusData)
        #expect(overrides.count == 1)
        #expect(overrides.first?.path == greetPath)
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
        let greetJSON = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(greetJSON.message == "Hello from API")

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: "status")
        )
        #expect(statusResponse.statusCode == 200)
        let overrides = try DemoServerE2EJSON.decodeOverrides(from: statusData)
        #expect(overrides.isEmpty)
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
        let overrides = try DemoServerE2EJSON.decodeOverrides(from: statusData)
        #expect(overrides.isEmpty)
    }

    // MARK: - E2E-10, E2E-11 (middleware + responseMap; handler stubs throw for unconfigured ops)

    @Test func listItemsReturnsSpecExampleViaConfigure() async throws {
        try await server.resetOverrides()

        let itemsPath = DemoServerE2EPaths.itemsListPath
        let configureBody = Data(
            """
            {"path":"\(itemsPath)","method":"GET","statusCode":200,"isEnabled":true}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let (response, data) = try await DemoServerHTTP.get(server.baseURL.appending(path: "items"))
        #expect(response.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(response))
        let items = try DemoServerE2EJSON.decodeItems(from: data)
        #expect(items.contains { $0.id == "item-1" && $0.name == "Example item" })
    }

    @Test func getItemByIdMatchesPathParameter() async throws {
        try await server.resetOverrides()

        let itemPath = DemoServerE2EPaths.itemByIDPathTemplate
        let configureBody = Data(
            """
            {"path":"\(itemPath)","method":"GET","statusCode":200,"isEnabled":true}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let (response, data) = try await DemoServerHTTP.get(server.baseURL.appending(path: "items/item-1"))
        #expect(response.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(response))
        let item = try DemoServerE2EJSON.decodeItem(from: data)
        #expect(item.id == "item-1")
        #expect(item.name == "Example item")
    }

    // MARK: - E2E-20 … E2E-26

    @Test func kawarimiSpecReturnsMetaAndEndpoints() async throws {
        try await server.resetOverrides()

        let (response, data) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: "spec")
        )
        #expect(response.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(response))
        let spec = try DemoServerE2EJSON.decodeSpec(from: data)
        #expect(!spec.endpoints.isEmpty)
        #expect(spec.meta.title == "GreetingService")
    }

    @Test func configureWithNamedExampleIdReturnsSpecBody() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,"exampleId":"formal"}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let body = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(body.message == "Good day from API")
    }

    @Test func disabledOverrideFallsThroughToHandler() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":false}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let body = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(body.message == "Hello from API")

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: "status")
        )
        #expect(statusResponse.statusCode == 200)
        let overrides = try DemoServerE2EJSON.decodeOverrides(from: statusData)
        #expect(overrides.count == 1)
        #expect(overrides.first?.isEnabled == false)
    }

    @Test func exampleIdHeaderSelectsOverride() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        for exampleId in ["success", "formal"] {
            let configureBody = Data(
                """
                {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,"exampleId":"\(exampleId)"}
                """.utf8
            )
            let (configureResponse, _) = try await DemoServerHTTP.postJSON(
                server.kawarimiBaseURL.appending(path: "configure"),
                body: configureBody
            )
            #expect(configureResponse.statusCode == 200)
        }

        let greetURL = server.baseURL.appending(path: "greet")
        let (formalResponse, formalData) = try await DemoServerHTTP.get(
            greetURL,
            headers: [DemoServerE2EConstants.exampleIdHeader: "formal"]
        )
        #expect(formalResponse.statusCode == 200)
        #expect(try DemoServerE2EJSON.decodeGreeting(from: formalData).message == "Good day from API")

        let (successResponse, successData) = try await DemoServerHTTP.get(
            greetURL,
            headers: [DemoServerE2EConstants.exampleIdHeader: "success"]
        )
        #expect(successResponse.statusCode == 200)
        #expect(try DemoServerE2EJSON.decodeGreeting(from: successData).message == "Hello from API")

        let (defaultResponse, defaultData) = try await DemoServerHTTP.get(greetURL)
        #expect(defaultResponse.statusCode == 200)
        // Tie-break: exampleId "formal" sorts before "success".
        #expect(try DemoServerE2EJSON.decodeGreeting(from: defaultData).message == "Good day from API")
    }

    @Test func configureRejectsInvalidJSON() async throws {
        try await server.resetOverrides()

        let (response, _) = try await DemoServerHTTP.post(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: Data("{".utf8),
            contentType: "application/json"
        )
        #expect(response.statusCode == 400)
    }

    @Test func configureRejectsOversizedBody() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let oversized = String(repeating: "x", count: MockOverride.maxBodyLength + 1)
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,\
            "body":"\(oversized)","contentType":"application/json"}
            """.utf8
        )
        let (response, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(response.statusCode == 413)
    }

    @Test func configureDelayMsDelaysResponse() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,"delayMs":400,\
            "body":"{\\"message\\":\\"Delayed\\"}","contentType":"application/json"}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: "configure"),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let start = ContinuousClock.now
        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        let elapsed = start.duration(to: ContinuousClock.now)
        #expect(greetResponse.statusCode == 200)
        #expect(try DemoServerE2EJSON.decodeGreeting(from: greetData).message == "Delayed")
        #expect(elapsed >= .milliseconds(250))
    }
}
#endif

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
        let (configureResponse, configureData) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(configureResponse))
        let configuredOverrides = try DemoServerE2EJSON.decodeOverrides(from: configureData)
        #expect(configuredOverrides.count == 1)
        #expect(configuredOverrides.first?.path == greetPath)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let greetJSON = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(greetJSON.message == "From E2E test")
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let resetURL = server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.reset.relativePath)
        let (resetResponse, resetData) = try await DemoServerHTTP.postEmpty(resetURL)
        #expect(resetResponse.statusCode == KawarimiAdminRoute.reset.successStatusCode)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(resetResponse))
        let resetOverrides = try DemoServerE2EJSON.decodeOverrides(from: resetData)
        #expect(resetOverrides.isEmpty)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let greetJSON = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(greetJSON.message == "Hello from API")

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.status.relativePath)
        )
        #expect(statusResponse.statusCode == 200)
        let overrides = try DemoServerE2EJSON.decodeOverrides(from: statusData)
        #expect(overrides.isEmpty)
    }

    @Test func hengeAdminRemoveDeletesEnabledOverrideRow() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let row = """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,"body":"{\\"message\\":\\"Stored\\"}"}
            """
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: Data(row.utf8)
        )
        #expect(configureResponse.statusCode == 200)

        let (removeResponse, removeData) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.remove.relativePath),
            body: Data(row.utf8)
        )
        #expect(removeResponse.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(removeResponse))
        let removedOverrides = try DemoServerE2EJSON.decodeOverrides(from: removeData)
        #expect(removedOverrides.isEmpty)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let greetJSON = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(greetJSON.message == "Hello from API")
    }

    @Test func hengeRemoveDeletesOverrideRow() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let row = """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":false}
            """
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: Data(row.utf8)
        )
        #expect(configureResponse.statusCode == 200)

        let (removeResponse, removeData) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.remove.relativePath),
            body: Data(row.utf8)
        )
        #expect(removeResponse.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(removeResponse))
        let removedOverrides = try DemoServerE2EJSON.decodeOverrides(from: removeData)
        #expect(removedOverrides.isEmpty)
    }

    @Test func hengeReloadReturns200WithOverridesAndReloadHeader() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let configureBody = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,\
            "body":"{\\"message\\":\\"Before reload\\"}","contentType":"application/json"}
            """.utf8
        )
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let reloadURL = server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.reload.relativePath)
        let (unchangedResponse, unchangedData) = try await DemoServerHTTP.postEmpty(reloadURL)
        #expect(unchangedResponse.statusCode == KawarimiAdminRoute.reload.successStatusCode)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(unchangedResponse))
        #expect(unchangedResponse.value(forHTTPHeaderField: KawarimiAdminHeaders.reloadOutcome) == "unchanged")
        let unchangedOverrides = try DemoServerE2EJSON.decodeOverrides(from: unchangedData)
        #expect(unchangedOverrides.count == 1)
        #expect(unchangedOverrides[0].body?.contains("Before reload") == true)

        let diskEdit = Data(
            """
            {"overrides":[{"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":true,\
            "body":"{\\"message\\":\\"After disk edit\\"}","contentType":"application/json"}]}
            """.utf8
        )
        try server.writeConfigOnDisk(diskEdit)

        let (appliedResponse, appliedData) = try await DemoServerHTTP.postEmpty(reloadURL)
        #expect(appliedResponse.statusCode == KawarimiAdminRoute.reload.successStatusCode)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(appliedResponse))
        #expect(appliedResponse.value(forHTTPHeaderField: KawarimiAdminHeaders.reloadOutcome) == "applied")
        let appliedOverrides = try DemoServerE2EJSON.decodeOverrides(from: appliedData)
        #expect(appliedOverrides.count == 1)
        #expect(appliedOverrides[0].body?.contains("After disk edit") == true)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        #expect(try DemoServerE2EJSON.decodeGreeting(from: greetData).message == "After disk edit")
    }

    @Test func hengeRemoveRejectsInvalidJSONBody() async throws {
        try await server.resetOverrides()

        let removeURL = server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.remove.relativePath)
        let (response, data) = try await DemoServerHTTP.postJSON(removeURL, body: Data("{not json}".utf8))
        #expect(response.statusCode == 400)
        let body = String(data: data, encoding: .utf8) ?? ""
        #expect(body.contains("Invalid JSON body"))
    }

    /// Legacy row: saved without `exampleId` but body matches OpenAPI `formal`. Henge Del sends wire identity (`exampleId` nil), not chip `exampleId: "formal"`.
    @Test func hengeRemoveMatchesLegacyRowWithoutExampleId() async throws {
        try await server.resetOverrides()

        let greetPath = DemoServerE2EPaths.greetPath
        let configureRow = """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":false,\
            "body":"{\\"message\\":\\"Good day from API\\"}","contentType":"application/json"}
            """
        let (configureResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: Data(configureRow.utf8)
        )
        #expect(configureResponse.statusCode == 200)

        let (statusBeforeResponse, statusBeforeData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.status.relativePath)
        )
        #expect(statusBeforeResponse.statusCode == 200)
        let before = try DemoServerE2EJSON.decodeOverrides(from: statusBeforeData)
        #expect(before.count == 1)
        #expect(before.first?.exampleId == nil)

        let removeWire = """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"isEnabled":false}
            """
        let (removeResponse, _) = try await DemoServerHTTP.postJSON(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.remove.relativePath),
            body: Data(removeWire.utf8)
        )
        #expect(removeResponse.statusCode == 200)

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.status.relativePath)
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.spec.relativePath)
        )
        #expect(response.statusCode == KawarimiAdminRoute.spec.successStatusCode)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(response))
        try KawarimiAdminSpecWire.validate(data)
        let spec = try DemoServerE2EJSON.decodeSpec(from: data)
        #expect(!spec.endpoints.isEmpty)
        #expect(spec.meta.title == "GreetingService")
        let hengeSpec = try DemoServerE2EJSON.decodeHengeSpec(from: data)
        #expect(hengeSpec.meta.title == spec.meta.title)
        #expect(hengeSpec.meta.apiPathPrefix == spec.meta.apiPathPrefix)
        #expect(hengeSpec.endpoints.count == spec.endpoints.count)
        let specDelete = try #require(spec.endpoints.first { $0.operationId == "deleteItem" })
        let hengeDelete = try #require(hengeSpec.endpoints.first { $0.operationId == "deleteItem" })
        #expect(hengeDelete.method == specDelete.method)
        #expect(hengeDelete.path == specDelete.path)

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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
            body: configureBody
        )
        #expect(configureResponse.statusCode == 200)

        let (greetResponse, greetData) = try await DemoServerHTTP.get(server.baseURL.appending(path: "greet"))
        #expect(greetResponse.statusCode == 200)
        let body = try DemoServerE2EJSON.decodeGreeting(from: greetData)
        #expect(body.message == "Hello from API")

        let (statusResponse, statusData) = try await DemoServerHTTP.get(
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.status.relativePath)
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
                server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
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
            server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath),
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

    @Test func scenarioGreetTwoStepTimeline() async throws {
        try await DemoServerE2EScenarioSupport.installGreetTwoStepScenario(on: server)

        let greetURL = server.baseURL.appending(path: "greet")
        let (firstResponse, firstData) = try await DemoServerHTTP.get(
            greetURL,
            headers: [KawarimiScenarioHeaders.scenarioId: DemoServerE2EScenarioSupport.scenarioId]
        )
        #expect(firstResponse.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(firstResponse))
        #expect(firstResponse.value(forHTTPHeaderField: KawarimiScenarioHeaders.nextKawarimiId) == "formal")
        #expect(
            try DemoServerE2EJSON.decodeGreeting(from: firstData).message
                == DemoServerE2EScenarioSupport.step1Message
        )

        let (secondResponse, secondData) = try await DemoServerHTTP.get(
            greetURL,
            headers: [
                KawarimiScenarioHeaders.scenarioId: DemoServerE2EScenarioSupport.scenarioId,
                KawarimiScenarioHeaders.kawarimiId: "formal",
            ]
        )
        #expect(secondResponse.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(secondResponse))
        #expect(secondResponse.value(forHTTPHeaderField: KawarimiScenarioHeaders.nextKawarimiId) == nil)
        #expect(
            try DemoServerE2EJSON.decodeGreeting(from: secondData).message
                == DemoServerE2EScenarioSupport.step2Message
        )

        try await DemoServerE2EScenarioSupport.installEmptyScenarios(on: server)
    }

    @Test func scenarioGreetReentryWithoutKawarimiIdRestartsAtInitial() async throws {
        try await DemoServerE2EScenarioSupport.installGreetTwoStepScenario(on: server)

        let greetURL = server.baseURL.appending(path: "greet")
        let scenarioHeader = [KawarimiScenarioHeaders.scenarioId: DemoServerE2EScenarioSupport.scenarioId]

        let (_, _) = try await DemoServerHTTP.get(greetURL, headers: scenarioHeader)
        let (_, _) = try await DemoServerHTTP.get(
            greetURL,
            headers: scenarioHeader.merging(
                [KawarimiScenarioHeaders.kawarimiId: "formal"],
                uniquingKeysWith: { _, new in new }
            )
        )

        let (reentryResponse, reentryData) = try await DemoServerHTTP.get(greetURL, headers: scenarioHeader)
        #expect(reentryResponse.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(reentryResponse))
        #expect(reentryResponse.value(forHTTPHeaderField: KawarimiScenarioHeaders.nextKawarimiId) == "formal")
        #expect(
            try DemoServerE2EJSON.decodeGreeting(from: reentryData).message
                == DemoServerE2EScenarioSupport.step1Message
        )

        try await DemoServerE2EScenarioSupport.installEmptyScenarios(on: server)
    }

    @Test func clientScenarioGreetTwoStepTimeline() async throws {
        try await DemoServerE2EScenarioSupport.installGreetTwoStepScenario(on: server)

        let transitions = ScenarioTransitionLog()
        let scenarioId = DemoServerE2EScenarioSupport.scenarioId
        let client = DemoServerE2EClientSupport.makeGreetingClient(
            baseURL: server.baseURL,
            scenarioId: scenarioId,
            onNextKawarimiId: { transitions.record(scenarioId: $0, nextKawarimiId: $1) }
        )

        let firstMessage = try DemoServerE2EClientSupport.greetingMessage(
            from: try await client.getGreeting(.init())
        )
        #expect(firstMessage == DemoServerE2EScenarioSupport.step1Message)

        let secondMessage = try DemoServerE2EClientSupport.greetingMessage(
            from: try await client.getGreeting(.init())
        )
        #expect(secondMessage == DemoServerE2EScenarioSupport.step2Message)

        let recorded = transitions.snapshot()
        #expect(recorded.count == 2)
        #expect(recorded[0].scenarioId == scenarioId)
        #expect(recorded[0].nextKawarimiId == "formal")
        #expect(recorded[1].scenarioId == scenarioId)
        #expect(recorded[1].nextKawarimiId == nil)

        try await DemoServerE2EScenarioSupport.installEmptyScenarios(on: server)
    }

    @Test func clientScenarioGreetReentryAfterTerminalRestartsAtInitial() async throws {
        try await DemoServerE2EScenarioSupport.installGreetTwoStepScenario(on: server)

        let transitions = ScenarioTransitionLog()
        let scenarioId = DemoServerE2EScenarioSupport.scenarioId
        let client = DemoServerE2EClientSupport.makeGreetingClient(
            baseURL: server.baseURL,
            scenarioId: scenarioId,
            onNextKawarimiId: { transitions.record(scenarioId: $0, nextKawarimiId: $1) }
        )

        _ = try await client.getGreeting(.init())
        _ = try await client.getGreeting(.init())

        let reentryMessage = try DemoServerE2EClientSupport.greetingMessage(
            from: try await client.getGreeting(.init())
        )
        #expect(reentryMessage == DemoServerE2EScenarioSupport.step1Message)

        let recorded = transitions.snapshot()
        #expect(recorded.count == 3)
        #expect(recorded[0].nextKawarimiId == "formal")
        #expect(recorded[1].nextKawarimiId == nil)
        #expect(recorded[2].nextKawarimiId == "formal")

        try await DemoServerE2EScenarioSupport.installEmptyScenarios(on: server)
    }

    @Test func scenarioCreateItemValidationOneStepError() async throws {
        try await DemoServerE2EScenarioSupport.installCreateItemValidationScenario(on: server)

        let itemsURL = server.baseURL.appending(path: "items")
        let createBody = Data(#"{"name":"Widget"}"#.utf8)
        let scenarioHeader = [
            KawarimiScenarioHeaders.scenarioId: DemoServerE2EScenarioSupport.createItemScenarioId,
        ]

        let (errorResponse, errorData) = try await DemoServerHTTP.post(
            itemsURL,
            body: createBody,
            contentType: "application/json",
            headers: scenarioHeader
        )
        #expect(errorResponse.statusCode == 400)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(errorResponse))
        #expect(errorResponse.value(forHTTPHeaderField: KawarimiScenarioHeaders.nextKawarimiId) == nil)
        let errorBody = try DemoServerE2EJSON.decodeError(from: errorData)
        #expect(errorBody.code == DemoServerE2EScenarioSupport.validationErrorCode)
        #expect(errorBody.message == DemoServerE2EScenarioSupport.validationErrorMessage)

        let (reentryResponse, reentryData) = try await DemoServerHTTP.post(
            itemsURL,
            body: createBody,
            contentType: "application/json",
            headers: scenarioHeader
        )
        #expect(reentryResponse.statusCode == 400)
        let reentryBody = try DemoServerE2EJSON.decodeError(from: reentryData)
        #expect(reentryBody.code == DemoServerE2EScenarioSupport.validationErrorCode)
        #expect(reentryBody.message == DemoServerE2EScenarioSupport.validationErrorMessage)

        try await DemoServerE2EScenarioSupport.installEmptyScenarios(on: server)
    }

    @Test func scenarioUnknownIdFallsBackToPrimaryOverride() async throws {
        try await server.resetOverrides()
        try await DemoServerE2EScenarioSupport.configureGreetOverride(
            on: server,
            message: DemoServerE2EScenarioSupport.fallbackMessage,
            isEnabled: true
        )
        try await DemoServerE2EScenarioSupport.installEmptyScenarios(on: server)

        let greetURL = server.baseURL.appending(path: "greet")
        let (response, data) = try await DemoServerHTTP.get(
            greetURL,
            headers: [KawarimiScenarioHeaders.scenarioId: "does-not-exist"]
        )
        #expect(response.statusCode == 200)
        #expect(DemoServerE2EHTTPChecks.isJSONContentType(response))
        #expect(response.value(forHTTPHeaderField: KawarimiScenarioHeaders.nextKawarimiId) == nil)
        #expect(
            try DemoServerE2EJSON.decodeGreeting(from: data).message
                == DemoServerE2EScenarioSupport.fallbackMessage
        )
    }
}
#endif

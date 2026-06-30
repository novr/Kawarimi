#if os(macOS) || os(Linux)
import Foundation
import KawarimiCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum DemoServerE2EScenarioSupport {
    static let scenarioId = "e2e-greet"
    static let step1Message = "Hello from E2E step 1"
    static let step2Message = "Good day from E2E step 2"
    static let fallbackMessage = "From scenario fallback E2E"

    static func installGreetTwoStepScenario(on server: DemoServerHarness) async throws {
        try await server.resetOverrides()

        let rowA = MockOverrideRowID.generate()
        let rowB = MockOverrideRowID.generate()
        let greetPath = DemoServerE2EPaths.greetPath
        let configureURL = server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath)

        try await configureGreetRow(
            url: configureURL,
            greetPath: greetPath,
            rowId: rowA,
            exampleId: "success",
            isEnabled: true,
            message: step1Message
        )
        try await configureGreetRow(
            url: configureURL,
            greetPath: greetPath,
            rowId: rowB,
            exampleId: "formal",
            isEnabled: false,
            message: step2Message
        )

        let scenarios = KawarimiScenariosFile(scenarios: [
            KawarimiScenario(
                scenarioId: scenarioId,
                initial: "success",
                cases: [
                    .init(
                        kawarimiId: "success",
                        next: "formal",
                        rowId: rowA,
                        endpoint: .init(method: "GET", path: greetPath)
                    ),
                    .init(
                        kawarimiId: "formal",
                        rowId: rowB,
                        endpoint: .init(method: "GET", path: greetPath)
                    ),
                ]
            ),
        ])
        let data = try JSONEncoder().encode(scenarios)
        try server.writeScenariosOnDisk(data)
        try await server.reloadFromDisk(expectingOutcome: "applied")
    }

    static func installEmptyScenarios(on server: DemoServerHarness) async throws {
        try server.writeScenariosOnDisk(Data("{\"scenarios\":[]}".utf8))
        _ = try await server.reloadFromDisk()
    }

    static func configureGreetOverride(
        on server: DemoServerHarness,
        message: String,
        isEnabled: Bool
    ) async throws {
        let rowId = MockOverrideRowID.generate()
        let configureURL = server.kawarimiBaseURL.appending(path: KawarimiAdminRoute.configure.relativePath)
        try await configureGreetRow(
            url: configureURL,
            greetPath: DemoServerE2EPaths.greetPath,
            rowId: rowId,
            exampleId: nil,
            isEnabled: isEnabled,
            message: message
        )
    }

    private static func configureGreetRow(
        url: URL,
        greetPath: String,
        rowId: MockOverrideRowID,
        exampleId: String?,
        isEnabled: Bool,
        message: String
    ) async throws {
        let exampleIdField: String
        if let exampleId {
            exampleIdField = """
            ,"exampleId":"\(exampleId)"
            """
        } else {
            exampleIdField = ""
        }
        let body = Data(
            """
            {"path":"\(greetPath)","method":"GET","statusCode":200,"rowId":"\(rowId.rawValue)",\
            "isEnabled":\(isEnabled)\(exampleIdField),\
            "body":"{\\"message\\":\\"\(message)\\"}","contentType":"application/json"}
            """.utf8
        )
        let (response, _) = try await DemoServerHTTP.postJSON(url, body: body)
        guard response.statusCode == 200 else {
            throw HarnessError.unexpectedHTTPStatus(response.statusCode, url: url, stderr: "configure failed")
        }
    }
}
#endif

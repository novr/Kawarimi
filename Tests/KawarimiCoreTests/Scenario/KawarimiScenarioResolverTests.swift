import Foundation
import HTTPTypes
import Testing

@testable import KawarimiCore

@Suite("KawarimiScenarioResolver")
struct KawarimiScenarioResolverTests {
    @Test func resolvesInitialWhenKawarimiIdHeaderMissing() {
        let rowId = MockOverrideRowID.generate()
        let scenarios = [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    KawarimiScenarioCase(
                        kawarimiId: "start",
                        next: "locked",
                        rowId: rowId,
                        endpoint: .init(method: "POST", path: "/api/login")
                    ),
                ]
            ),
        ]
        let overrides = [
            MockOverride(
                rowId: rowId,
                path: "/api/login",
                method: .post,
                statusCode: 401,
                body: "{\"error\":true}",
                contentType: "application/json"
            ),
        ]

        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: scenarios,
            overrides: overrides,
            responseMap: [:],
            requestPath: "/api/login",
            method: .post,
            scenarioIdHeaderRaw: "login",
            kawarimiIdHeaderRaw: nil
        )

        guard case .matched(let response, let next, _, _) = resolved else {
            Issue.record("Expected matched response")
            return
        }
        #expect(response.statusCode == 401)
        #expect(next == "locked")
    }

    @Test func resolvesFailureModeFromOverride() {
        let rowId = MockOverrideRowID.generate()
        let scenarios = [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    KawarimiScenarioCase(
                        kawarimiId: "start",
                        next: nil,
                        rowId: rowId,
                        endpoint: .init(method: "POST", path: "/api/login")
                    ),
                ]
            ),
        ]
        let overrides = [
            MockOverride(
                rowId: rowId,
                path: "/api/login",
                method: .post,
                statusCode: 503,
                body: nil,
                contentType: nil,
                delayMs: 100,
                failureMode: .connectionClose
            ),
        ]

        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: scenarios,
            overrides: overrides,
            responseMap: [:],
            requestPath: "/api/login",
            method: .post,
            scenarioIdHeaderRaw: "login",
            kawarimiIdHeaderRaw: "start"
        )

        guard case .matched(_, _, let delayMs, let failureMode) = resolved else {
            Issue.record("Expected matched response")
            return
        }
        #expect(delayMs == 100)
        #expect(failureMode == .connectionClose)
    }

    @Test func fallsBackOnDuplicateCaseKey() {
        let rowA = MockOverrideRowID.generate()
        let rowB = MockOverrideRowID.generate()
        let scenarios = [
            KawarimiScenario(
                scenarioId: "dup",
                initial: "a",
                cases: [
                    .init(kawarimiId: "a", next: "b", rowId: rowA, endpoint: .init(method: "GET", path: "/api/x")),
                    .init(kawarimiId: "a", next: "c", rowId: rowB, endpoint: .init(method: "GET", path: "/api/x")),
                ]
            ),
        ]

        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: scenarios,
            overrides: [],
            responseMap: [:],
            requestPath: "/api/x",
            method: .get,
            scenarioIdHeaderRaw: "dup",
            kawarimiIdHeaderRaw: "a"
        )

        #expect(resolved == .fallback(reason: .duplicateCases))
    }

    @Test func fallsBackWhenRowIdEndpointMismatch() {
        let rowId = MockOverrideRowID.generate()
        let scenarios = [
            KawarimiScenario(
                scenarioId: "mismatch",
                initial: "start",
                cases: [
                    .init(kawarimiId: "start", next: nil, rowId: rowId, endpoint: .init(method: "GET", path: "/api/items")),
                ]
            ),
        ]
        let overrides = [
            MockOverride(
                rowId: rowId,
                path: "/api/other",
                method: .get,
                statusCode: 200,
                body: "{}",
                contentType: "application/json"
            ),
        ]

        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: scenarios,
            overrides: overrides,
            responseMap: [:],
            requestPath: "/api/items",
            method: .get,
            scenarioIdHeaderRaw: "mismatch",
            kawarimiIdHeaderRaw: "start"
        )

        #expect(resolved == .fallback(reason: .endpointMismatch))
    }

    @Test func fallsBackWhenInitialInvalid() {
        let scenarios = [
            KawarimiScenario(
                scenarioId: "bad",
                initial: "bad token!",
                cases: []
            ),
        ]

        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: scenarios,
            overrides: [],
            responseMap: [:],
            requestPath: "/api/items",
            method: .get,
            scenarioIdHeaderRaw: "bad",
            kawarimiIdHeaderRaw: nil
        )

        #expect(resolved == .fallback(reason: .invalidHeader))
    }

    @Test func fallsBackWhenScenarioHeaderMissing() {
        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: [],
            overrides: [],
            responseMap: [:],
            requestPath: "/api/items",
            method: .get,
            scenarioIdHeaderRaw: nil,
            kawarimiIdHeaderRaw: nil
        )

        #expect(resolved == .fallback(reason: .scenarioHeaderMissing))
    }

    @Test func fallsBackWhenScenarioIdHeaderInvalid() {
        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: [],
            overrides: [],
            responseMap: [:],
            requestPath: "/api/items",
            method: .get,
            scenarioIdHeaderRaw: "bad token!",
            kawarimiIdHeaderRaw: nil
        )

        #expect(resolved == .fallback(reason: .invalidHeader))
    }

    @Test func fallsBackWhenScenarioNotFound() {
        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: [],
            overrides: [],
            responseMap: [:],
            requestPath: "/api/items",
            method: .get,
            scenarioIdHeaderRaw: "missing",
            kawarimiIdHeaderRaw: nil
        )

        #expect(resolved == .fallback(reason: .scenarioNotFound))
    }

    @Test func fallsBackWhenCaseNotFound() {
        let rowId = MockOverrideRowID.generate()
        let scenarios = [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    .init(
                        kawarimiId: "start",
                        next: "locked",
                        rowId: rowId,
                        endpoint: .init(method: "POST", path: "/api/login")
                    ),
                ]
            ),
        ]

        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: scenarios,
            overrides: [],
            responseMap: [:],
            requestPath: "/api/login",
            method: .post,
            scenarioIdHeaderRaw: "login",
            kawarimiIdHeaderRaw: "unknown"
        )

        #expect(resolved == .fallback(reason: .caseNotFound))
    }

    @Test func fallsBackWhenOverrideNotFound() {
        let rowId = MockOverrideRowID.generate()
        let scenarios = [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    .init(
                        kawarimiId: "start",
                        next: nil,
                        rowId: rowId,
                        endpoint: .init(method: "POST", path: "/api/login")
                    ),
                ]
            ),
        ]

        let resolved = KawarimiScenarioResolver.resolve(
            scenarios: scenarios,
            overrides: [],
            responseMap: [:],
            requestPath: "/api/login",
            method: .post,
            scenarioIdHeaderRaw: "login",
            kawarimiIdHeaderRaw: "start"
        )

        #expect(resolved == .fallback(reason: .overrideNotFound))
    }
}

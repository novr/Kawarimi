import Foundation
import HTTPTypes
import Testing

@testable import KawarimiCore

@Suite("MockOverrideRequestMatching", .timeLimit(.minutes(1)))
struct MockOverrideRequestMatchingTests {
    @Test(.timeLimit(.minutes(1))) func matchesIncomingRequestByPathTemplate() {
        let override = MockOverride(path: "/api/users/{id}", method: .get, statusCode: 200)
        #expect(
            MockOverrideRequestMatching.overrideMatchesIncomingRequest(
                override,
                requestPath: "/api/users/42",
                method: .get,
                operationID: nil,
                pathPrefix: "/api"
            )
        )
    }

    @Test(.timeLimit(.minutes(1))) func matchesIncomingRequestByOperationID() {
        let override = MockOverride(
            name: "getUser",
            path: "/api/users/{id}",
            method: .get,
            statusCode: 200
        )
        #expect(
            MockOverrideRequestMatching.overrideMatchesIncomingRequest(
                override,
                requestPath: "/api/users/99",
                method: .get,
                operationID: "getUser",
                pathPrefix: "/api"
            )
        )
    }

    @Test(.timeLimit(.minutes(1))) func matchesOperationByAlignedPath() {
        let override = MockOverride(path: "/api/items", method: .get, statusCode: 200)
        #expect(
            MockOverrideRequestMatching.overrideMatchesOperation(
                override,
                method: .get,
                operationPath: "/items",
                operationID: nil,
                pathPrefix: "/api"
            )
        )
    }

    @Test(.timeLimit(.minutes(1))) func matchesOperationByOperationIDIgnoresPathTypo() {
        let override = MockOverride(
            name: "listItems",
            path: "/api/wrong-path",
            method: .get,
            statusCode: 200,
            isEnabled: true
        )
        #expect(
            MockOverrideRequestMatching.overrideMatchesOperation(
                override,
                method: .get,
                operationPath: "/api/items",
                operationID: "listItems",
                pathPrefix: "/api"
            )
        )
    }

    @Test(.timeLimit(.minutes(1))) func primaryForOperationUsesTieBreakOrder() {
        let laterPath = MockOverride(path: "/api/zebra", method: .get, statusCode: 200, isEnabled: true)
        let earlierPath = MockOverride(path: "/api/apple", method: .get, statusCode: 200, isEnabled: true)
        let primary = MockOverrideRequestMatching.primaryEnabledOverrideForOperation(
            in: [laterPath, earlierPath],
            method: .get,
            operationPath: "/api/apple",
            operationID: nil,
            pathPrefix: "/api"
        )
        #expect(primary?.path == "/api/apple")
    }

    @Test(.timeLimit(.minutes(1))) func matchingEnabledOverridesForOperationExcludesDisabled() {
        let enabled = MockOverride(path: "/api/items", method: .get, statusCode: 200, isEnabled: true)
        let disabled = MockOverride(path: "/api/items", method: .get, statusCode: 404, isEnabled: false)
        let matches = MockOverrideRequestMatching.matchingEnabledOverridesForOperation(
            in: [enabled, disabled],
            method: .get,
            operationPath: "/api/items",
            operationID: nil,
            pathPrefix: "/api"
        )
        #expect(matches == [enabled])
    }

    @Test(.timeLimit(.minutes(1))) func primaryRespectsExampleIdHeader() {
        let defaultRow = MockOverride(
            path: "/api/items",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true
        )
        let altRow = MockOverride(
            path: "/api/items",
            method: .get,
            statusCode: 200,
            exampleId: "alt",
            isEnabled: true
        )
        let primary = MockOverrideRequestMatching.primaryEnabledOverride(
            in: [defaultRow, altRow],
            requestPath: "/api/items",
            method: .get,
            operationID: nil,
            pathPrefix: "/api",
            exampleIdHeaderRaw: "alt"
        )
        #expect(primary?.exampleId == "alt")
    }
}

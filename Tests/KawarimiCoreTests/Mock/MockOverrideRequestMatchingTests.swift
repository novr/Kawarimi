import Foundation
import HTTPTypes
import Testing

@testable import KawarimiCore

@Suite("MockOverrideRequestMatching")
struct MockOverrideRequestMatchingTests {
    @Test func matchesIncomingRequestByPathTemplate() {
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

    @Test func matchesIncomingRequestByOperationID() {
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

    @Test func primaryRespectsExampleIdHeader() {
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

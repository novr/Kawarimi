import Foundation
import Testing

@testable import KawarimiCore

@Suite("KawarimiDynamicMockResponseResolver", .timeLimit(.minutes(1)))
struct KawarimiDynamicMockResponseResolverTests {
    @Test(.timeLimit(.minutes(1))) func usesCustomBodyWhenSet() {
        let override = MockOverride(
            path: "/api/x",
            method: .get,
            statusCode: 418,
            body: "{\"ok\":true}",
            contentType: "application/json"
        )
        let resolved = KawarimiDynamicMockResponseResolver.resolve(
            override: override,
            responseMap: [:],
            methodUppercased: "GET"
        )
        #expect(resolved.statusCode == 418)
        #expect(resolved.body == "{\"ok\":true}")
        #expect(resolved.contentType == "application/json")
    }

    @Test(.timeLimit(.minutes(1))) func fallsBackToEmptyJsonWhenNoSpecEntry() {
        let override = MockOverride(path: "/api/x", method: .get, statusCode: 503)
        let resolved = KawarimiDynamicMockResponseResolver.resolve(
            override: override,
            responseMap: [:],
            methodUppercased: "GET"
        )
        #expect(resolved.statusCode == 503)
        #expect(resolved.body == "{}")
    }
}

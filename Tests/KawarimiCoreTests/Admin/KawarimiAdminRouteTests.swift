import Foundation
import HTTPTypes
import KawarimiCore
import Testing

@Test func kawarimiAdminRouteContract() {
    #expect(KawarimiAdminRoute.spec.httpMethod == .get)
    #expect(KawarimiAdminRoute.spec.relativePath == "spec")
    #expect(KawarimiAdminRoute.spec.successStatusCode == 200)

    #expect(KawarimiAdminRoute.status.httpMethod == .get)
    #expect(KawarimiAdminRoute.status.relativePath == "status")
    #expect(KawarimiAdminRoute.status.successStatusCode == 200)

    #expect(KawarimiAdminRoute.configure.httpMethod == .post)
    #expect(KawarimiAdminRoute.configure.relativePath == "configure")
    #expect(KawarimiAdminRoute.configure.successStatusCode == 200)

    #expect(KawarimiAdminRoute.remove.httpMethod == .post)
    #expect(KawarimiAdminRoute.remove.relativePath == "remove")
    #expect(KawarimiAdminRoute.remove.successStatusCode == 200)

    #expect(KawarimiAdminRoute.reset.httpMethod == .post)
    #expect(KawarimiAdminRoute.reset.relativePath == "reset")
    #expect(KawarimiAdminRoute.reset.successStatusCode == 200)

    #expect(KawarimiAdminRoute.reload.httpMethod == .post)
    #expect(KawarimiAdminRoute.reload.relativePath == "reload")
    #expect(KawarimiAdminRoute.reload.successStatusCode == 200)
}

@Test func kawarimiAdminRouteAdminURLMatchesLegacyClientPaths() {
    let baseWithoutSlash = URL(string: "http://127.0.0.1:8080/api")!
    let baseWithSlash = URL(string: "http://127.0.0.1:8080/api/")!

    for route in KawarimiAdminRoute.allCases {
        let built = KawarimiAdminRoute.adminURL(baseURL: baseWithoutSlash, route: route)
        let legacy = baseWithoutSlash
            .appendingPathComponent("__kawarimi")
            .appendingPathComponent(route.relativePath)
        #expect(built == legacy)

        let builtFromSlashBase = KawarimiAdminRoute.adminURL(baseURL: baseWithSlash, route: route)
        let legacyFromSlashBase = baseWithSlash
            .appendingPathComponent("__kawarimi")
            .appendingPathComponent(route.relativePath)
        #expect(builtFromSlashBase == legacyFromSlashBase)
    }
}

@Test func kawarimiAdminRouteInitRoundTrip() {
    for route in KawarimiAdminRoute.allCases {
        let resolved = KawarimiAdminRoute(relativePath: route.relativePath, httpMethod: route.httpMethod)
        #expect(resolved == route)
    }

    #expect(KawarimiAdminRoute(relativePath: "spec", httpMethod: .post) == nil)
    #expect(KawarimiAdminRoute(relativePath: "unknown", httpMethod: .get) == nil)
}

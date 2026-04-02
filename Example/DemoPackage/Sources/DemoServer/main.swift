#if os(macOS)
import DemoAPI
import Foundation
import KawarimiCore
import OpenAPIVapor
import Vapor

enum DemoServerError: Error {
    case invalidStubURL
}

@main
struct DemoServer {
    static func main() async throws {
        let app = try await Application.make()
        let configPath = ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "kawarimi.json"
        let store = try KawarimiConfigStore(
            configPath: configPath,
            pathPrefix: KawarimiSpec.meta.apiPathPrefix
        )
        await registerKawarimiRoutes(app: app, store: store)
        app.middleware.use(KawarimiInterceptorMiddleware(store: store))
        let transport = VaporTransport(routesBuilder: app)
        let handler = KawarimiHandler()
        guard let serverURL = OpenAPIPathPrefix.stubServerURL(pathPrefix: await store.pathPrefix) else {
            throw DemoServerError.invalidStubURL
        }
        try handler.registerHandlers(on: transport, serverURL: serverURL)
        try await app.execute()
    }
}
#else
import Darwin

/// Vapor server is macOS-only; stub so the package resolves on iOS.
@main
enum DemoServer {
    static func main() {
        fputs("DemoServer runs on macOS only.\n", stderr)
        exit(1)
    }
}
#endif

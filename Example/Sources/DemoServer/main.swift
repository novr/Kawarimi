import DemoAPI
import Foundation
import KawarimiCore
import OpenAPIVapor
import Vapor

@main
struct DemoServer {
    static func main() async throws {
        let app = try await Application.make()
        let configPath = ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "config.json"
        let store = HengeConfigStore(configPath: configPath)
        registerHengeRoutes(app: app, store: store)
        app.middleware.use(HengeInterceptorMiddleware(store: store))
        let transport = VaporTransport(routesBuilder: app)
        let handler = KawarimiHandler()
        try handler.registerHandlers(on: transport, serverURL: URL(string: "/api")!)
        try await app.execute()
    }
}

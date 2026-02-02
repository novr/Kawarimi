import DemoAPI
import Foundation
import OpenAPIVapor
import Vapor

@main
struct DemoServer {
    static func main() async throws {
        let app = try await Application.make()
        let transport = VaporTransport(routesBuilder: app)
        let handler = KawarimiHandler()
        try handler.registerHandlers(on: transport, serverURL: URL(string: "/api")!)
        try await app.execute()
    }
}

import DemoAPI
import Foundation
import KawarimiCore
import Vapor

extension MockOverride: @retroactive Content {}
extension SpecResponse: Content {}

func registerHengeRoutes(app: Application, store: HengeConfigStore) {
    app.group("__kawarimi") { henge in
        henge.post("configure") { req async throws -> Response in
            let override: MockOverride
            do {
                override = try req.content.decode(MockOverride.self)
            } catch {
                return Response(status: .badRequest, body: .init(string: "Invalid JSON body: \(error)"))
            }
            do {
                try await store.configure(override)
                return Response(status: .ok)
            } catch {
                return Response(status: .internalServerError, body: .init(string: "\(error)"))
            }
        }

        henge.get("status") { req async throws -> Response in
            let overrides = await store.overrides()
            let data = try JSONEncoder().encode(overrides)
            var headers = HTTPHeaders()
            headers.contentType = .json
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }

        henge.post("reset") { req async throws -> Response in
            try await store.reset()
            return Response(status: .ok)
        }

        henge.get("spec") { _ async throws -> SpecResponse in
            SpecResponse(meta: KawarimiSpec.meta, endpoints: KawarimiSpec.endpoints)
        }
    }
}

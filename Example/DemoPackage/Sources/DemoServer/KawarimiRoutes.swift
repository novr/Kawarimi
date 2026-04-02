#if os(macOS)
import DemoAPI
import Foundation
import KawarimiCore
import Vapor

extension MockOverride: @retroactive Content {}
extension SpecResponse: Content {}

/// Nest under the same `pathPrefix` as OpenAPI or client base URLs drift from admin routes.
func registerKawarimiRoutes(app: Application, store: KawarimiConfigStore) async {
    let pathPrefix = await store.pathPrefix
    let segments = pathPrefix.split(separator: "/").filter { !$0.isEmpty }.map(String.init)

    func mountKawarimi(on builder: RoutesBuilder) {
        builder.group("__kawarimi") { kawarimi in
            kawarimi.post("configure") { req async throws -> Response in
                let override: MockOverride
                do {
                    override = try req.content.decode(MockOverride.self)
                } catch {
                    return Response(status: .badRequest, body: .init(string: "Invalid JSON body: \(error)"))
                }
                if let body = override.body, body.utf8.count > MockOverride.maxBodyLength {
                    return Response(
                        status: .payloadTooLarge,
                        body: .init(string: "Override body exceeds \(MockOverride.maxBodyLength) bytes")
                    )
                }
                do {
                    try await store.configure(override)
                    return Response(status: .ok)
                } catch let e as KawarimiConfigStoreError {
                    if case .bodyTooLong = e {
                        return Response(status: .payloadTooLarge, body: .init(string: "\(e)"))
                    }
                    return Response(status: .internalServerError, body: .init(string: "\(e)"))
                } catch {
                    return Response(status: .internalServerError, body: .init(string: "\(error)"))
                }
            }

            kawarimi.get("status") { _ async throws -> Response in
                let overrides = await store.overrides()
                let data = try JSONEncoder().encode(overrides)
                var headers = HTTPHeaders()
                headers.contentType = .json
                return Response(status: .ok, headers: headers, body: .init(data: data))
            }

            kawarimi.post("reset") { _ async throws -> Response in
                try await store.reset()
                return Response(status: .ok)
            }

            kawarimi.get("spec") { _ async throws -> SpecResponse in
                SpecResponse(meta: KawarimiSpec.meta, endpoints: KawarimiSpec.endpoints)
            }
        }
    }

    func nest(parent: RoutesBuilder, segmentIndex: Int) {
        if segmentIndex >= segments.count {
            mountKawarimi(on: parent)
            return
        }
        parent.group(PathComponent(stringLiteral: segments[segmentIndex])) { child in
            nest(parent: child, segmentIndex: segmentIndex + 1)
        }
    }

    nest(parent: app, segmentIndex: 0)
}
#endif

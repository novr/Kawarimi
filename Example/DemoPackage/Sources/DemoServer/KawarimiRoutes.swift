#if os(macOS) || os(Linux)
import DemoAPI
import Foundation
import KawarimiCore
import Vapor

extension MockOverride: @retroactive Content {}

/// Nest under the same `pathPrefix` as OpenAPI or client base URLs drift from admin routes.
func registerKawarimiRoutes(app: Application, store: KawarimiConfigStore) async {
    let pathPrefix = await store.pathPrefix
    let segments = pathPrefix.split(separator: "/").filter { !$0.isEmpty }.map(String.init)

    func mountKawarimi(on builder: RoutesBuilder) {
        builder.group(PathComponent(stringLiteral: KawarimiAdminPath.managementSegment)) { kawarimi in
            kawarimi.post(PathComponent(stringLiteral: KawarimiAdminRoute.configure.relativePath)) { req async throws -> Response in
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
                    return Response(status: adminSuccessHTTPStatus(for: .configure))
                } catch let e as KawarimiConfigStoreError {
                    if case .bodyTooLong = e {
                        return Response(status: .payloadTooLarge, body: .init(string: "\(e)"))
                    }
                    return Response(status: .internalServerError, body: .init(string: "\(e)"))
                } catch {
                    return Response(status: .internalServerError, body: .init(string: "\(error)"))
                }
            }

            kawarimi.post(PathComponent(stringLiteral: KawarimiAdminRoute.remove.relativePath)) { req async throws -> Response in
                let override: MockOverride
                do {
                    override = try req.content.decode(MockOverride.self)
                } catch {
                    return Response(status: .badRequest, body: .init(string: "Invalid JSON body: \(error)"))
                }
                do {
                    try await store.removeOverride(override)
                    return Response(status: adminSuccessHTTPStatus(for: .remove))
                } catch {
                    return Response(status: .internalServerError, body: .init(string: "\(error)"))
                }
            }

            kawarimi.get(PathComponent(stringLiteral: KawarimiAdminRoute.status.relativePath)) { _ async throws -> Response in
                let overrides = await store.overrides()
                let data = try JSONEncoder().encode(overrides)
                var headers = HTTPHeaders()
                headers.contentType = .json
                return Response(status: adminSuccessHTTPStatus(for: .status), headers: headers, body: .init(data: data))
            }

            kawarimi.post(PathComponent(stringLiteral: KawarimiAdminRoute.reset.relativePath)) { _ async throws -> Response in
                try await store.reset()
                return Response(status: adminSuccessHTTPStatus(for: .reset))
            }

            kawarimi.post(PathComponent(stringLiteral: KawarimiAdminRoute.reload.relativePath)) { _ async throws -> Response in
                let result = await store.reloadFromDisk()
                let overrides = await store.overrides()
                let data = try JSONEncoder().encode(overrides)
                var headers = HTTPHeaders()
                headers.add(name: KawarimiAdminHeaders.reloadOutcome, value: result.httpHeaderValue)
                headers.contentType = .json
                return Response(
                    status: adminSuccessHTTPStatus(for: .reload),
                    headers: headers,
                    body: .init(data: data)
                )
            }

            kawarimi.get(PathComponent(stringLiteral: KawarimiAdminRoute.spec.relativePath)) { _ async throws -> Response in
                let data = try DemoServerSpecResponse.encodedWireData()
                var headers = HTTPHeaders()
                headers.add(name: .contentType, value: KawarimiAdminHeaders.jsonContentType)
                return Response(
                    status: adminSuccessHTTPStatus(for: .spec),
                    headers: headers,
                    body: .init(data: data)
                )
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

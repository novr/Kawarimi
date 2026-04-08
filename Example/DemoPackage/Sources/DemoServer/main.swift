#if os(macOS)
import DemoAPI
import Foundation
import KawarimiCore
import OpenAPIVapor
import Vapor

enum DemoServerError: Error {
    case invalidStubURL
}

private func resolvedKawarimiConfigPath() -> String {
    if let env = ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"], !env.isEmpty {
        return env
    }
    let cwd = FileManager.default.currentDirectoryPath
    let name = KawarimiConfigDefaults.fileName
    let cwdCandidate = (cwd as NSString).appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: cwdCandidate) {
        return name
    }
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(name).path
}

@main
struct DemoServer {
    static func main() async throws {
        let app = try await Application.make()
        let configPath = resolvedKawarimiConfigPath()
        let store = try KawarimiConfigStore(
            configPath: configPath,
            pathPrefix: KawarimiSpec.meta.apiPathPrefix
        )
        await registerKawarimiRoutes(app: app, store: store)
        app.middleware.use(KawarimiInterceptorMiddleware(store: store))
        let transport = VaporTransport(routesBuilder: app)
        let handler = KawarimiHandler()
        let stubPath = KawarimiPath.joinPathPrefix(KawarimiPath.splitPathSegments(await store.pathPrefix))
        var stubComponents = URLComponents()
        stubComponents.scheme = "https"
        stubComponents.host = "kawarimi.openapi.invalid"
        stubComponents.path = stubPath.isEmpty ? "/" : stubPath
        guard let serverURL = stubComponents.url else {
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

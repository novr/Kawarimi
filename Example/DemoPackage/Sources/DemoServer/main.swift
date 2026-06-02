#if os(macOS) || os(Linux)
import DemoAPI
import Foundation
import KawarimiCore
import KawarimiServer
import OpenAPIVapor
import Vapor

enum DemoServerError: Error, LocalizedError {
    case invalidStubURL
    case invalidSpecWire(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidStubURL:
            "Could not build stub server URL for OpenAPI handler registration"
        case .invalidSpecWire(let underlying):
            "Spec wire JSON failed HengeSpecSnapshot validation: \(underlying)"
        }
    }
}

private func applyListenConfiguration(to app: Application) {
    let env = ProcessInfo.processInfo.environment
    if let host = env["HOST"], !host.isEmpty {
        app.http.server.configuration.hostname = host
    }
    if let portString = env["PORT"], let port = Int(portString) {
        app.http.server.configuration.port = port
    }
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
        do {
            try DemoServerSpecResponse.validateWireAtStartup()
        } catch {
            throw DemoServerError.invalidSpecWire(underlying: error)
        }

        let app = try await Application.make()
        applyListenConfiguration(to: app)
        let launch = DemoServerLaunchOptions.parse()
        if launch.listenReadyFile != nil || launch.printListenURLToStdout {
            app.lifecycle.use(
                ListenReadyNotifier(
                    readyFilePath: launch.listenReadyFile,
                    printToStdout: launch.printListenURLToStdout
                )
            )
        }
        let configPath = resolvedKawarimiConfigPath()
        let store = try KawarimiConfigStore(
            configPath: configPath,
            pathPrefix: KawarimiSpec.meta.apiPathPrefix
        )
        await store.startFileWatchIfEnabled()
        await registerKawarimiRoutes(app: app, store: store)
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
        try handler.registerHandlers(
            on: transport,
            serverURL: serverURL,
            middlewares: [KawarimiServerMiddleware(store: store, responseMap: KawarimiSpec.responseMap)]
        )
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

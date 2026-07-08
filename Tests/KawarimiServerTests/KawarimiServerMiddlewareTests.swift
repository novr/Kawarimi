import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiServer

@Suite("KawarimiServerMiddleware", .timeLimit(.minutes(1)))
struct KawarimiServerMiddlewareTests {
  @Test(.timeLimit(.minutes(1))) func returnsMockWithoutCallingNext() async throws {
    let configURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    let config = KawarimiConfig(overrides: [
      MockOverride(
        path: "/api/widgets",
        method: .get,
        statusCode: 201,
        body: "{\"mocked\":true}",
        contentType: "application/json"
      ),
    ])
    let data = try JSONEncoder().encode(config)
    try data.write(to: configURL)
    defer { try? FileManager.default.removeItem(at: configURL) }

    let store = try KawarimiConfigStore(configPath: configURL.path, pathPrefix: "/api")
    let middleware = KawarimiServerMiddleware(store: store, responseMap: [:])
  final class NextFlag: @unchecked Sendable { var value = false }
  let nextCalled = NextFlag()
    let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/widgets")
    let (response, body) = try await middleware.intercept(
      request,
      body: nil,
      metadata: ServerRequestMetadata(),
      operationID: "listWidgets",
      next: { _, _, _ in
        nextCalled.value = true
        return (HTTPResponse(status: .ok), nil)
      }
    )
    #expect(!nextCalled.value)
    #expect(response.status.code == 201)
    #expect(response.headerFields[.contentType] == "application/json")
    let collected = try await String(collecting: body!, upTo: 1024)
    #expect(collected == "{\"mocked\":true}")
  }

  @Test(.timeLimit(.minutes(1))) func reloadFromDisk_appliesHandEditedConfig() async throws {
    let configURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    let store = try KawarimiConfigStore(configPath: configURL.path, pathPrefix: "/api")
    try await store.configure(
      MockOverride(
        path: "/api/widgets",
        method: .get,
        statusCode: 201,
        body: "{\"before\":true}",
        contentType: "application/json"
      )
    )
    let onDisk = KawarimiConfig(overrides: [
      MockOverride(
        path: "/api/widgets",
        method: .get,
        statusCode: 201,
        body: "{\"after\":true}",
        contentType: "application/json"
      ),
    ])
    try JSONEncoder().encode(onDisk).write(to: configURL, options: .atomic)
    defer { try? FileManager.default.removeItem(at: configURL) }

    #expect(await store.reloadFromDisk() == .applied)
    let middleware = KawarimiServerMiddleware(store: store, responseMap: [:])
    let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/widgets")
    let (response, body) = try await middleware.intercept(
      request,
      body: nil,
      metadata: ServerRequestMetadata(),
      operationID: "listWidgets",
      next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
    )
    #expect(response.status.code == 201)
    let collected = try await String(collecting: body!, upTo: 1024)
    #expect(collected == "{\"after\":true}")
  }

  @Test(.timeLimit(.minutes(1))) func scenarioMatchReturnsMockAndNextHeader() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let configPath = dir.appendingPathComponent("kawarimi.json").path
    let scenarioPath = dir.appendingPathComponent("kawarimi-scenarios.json").path
    let rowId = MockOverrideRowID.generate()
    let store = try KawarimiConfigStore(configPath: configPath, pathPrefix: "/api", scenariosPath: scenarioPath)
    try await store.configure(
      MockOverride(
        rowId: rowId,
        path: "/api/login",
        method: .post,
        statusCode: 401,
        body: "{\"error\":true}",
        contentType: "application/json"
      )
    )
    let scenarios = KawarimiScenariosFile(scenarios: [
      KawarimiScenario(
        scenarioId: "login",
        initial: "start",
        cases: [
          .init(
            kawarimiId: "start",
            next: "locked",
            rowId: rowId,
            endpoint: .init(method: "POST", path: "/api/login")
          ),
        ]
      ),
    ])
    try JSONEncoder().encode(scenarios).write(to: URL(fileURLWithPath: scenarioPath), options: .atomic)
    _ = await store.reloadFromDisk()

    let middleware = KawarimiServerMiddleware(store: store, responseMap: [:])
    var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
    request.headerFields[HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!] = "login"

    let (response, body) = try await middleware.intercept(
      request,
      body: nil,
      metadata: ServerRequestMetadata(),
      operationID: "login",
      next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
    )
    #expect(response.status.code == 401)
    #expect(response.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] == "locked")
    let collected = try await String(collecting: body!, upTo: 1024)
    #expect(collected == "{\"error\":true}")
  }

  @Test(.timeLimit(.minutes(1))) func scenarioFallbackUsesExistingOverridePath() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let configPath = dir.appendingPathComponent("kawarimi.json").path
    let scenarioPath = dir.appendingPathComponent("kawarimi-scenarios.json").path
    let store = try KawarimiConfigStore(configPath: configPath, pathPrefix: "/api", scenariosPath: scenarioPath)
    try await store.configure(
      MockOverride(
        path: "/api/widgets",
        method: .get,
        statusCode: 201,
        body: "{\"from\":\"override\"}",
        contentType: "application/json"
      )
    )
    try Data("{\"scenarios\":[]}".utf8).write(to: URL(fileURLWithPath: scenarioPath), options: .atomic)
    _ = await store.reloadFromDisk()

    let middleware = KawarimiServerMiddleware(store: store, responseMap: [:])
    var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/widgets")
    request.headerFields[HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!] = "missing"

    let (response, body) = try await middleware.intercept(
      request,
      body: nil,
      metadata: ServerRequestMetadata(),
      operationID: "listWidgets",
      next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
    )
    #expect(response.status.code == 201)
    let collected = try await String(collecting: body!, upTo: 1024)
    #expect(collected == "{\"from\":\"override\"}")
  }

  @Test(.timeLimit(.minutes(1))) func scenarioTerminalCaseOmitsNextHeader() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let configPath = dir.appendingPathComponent("kawarimi.json").path
    let scenarioPath = dir.appendingPathComponent("kawarimi-scenarios.json").path
    let rowId = MockOverrideRowID.generate()
    let store = try KawarimiConfigStore(configPath: configPath, pathPrefix: "/api", scenariosPath: scenarioPath)
    try await store.configure(
      MockOverride(
        rowId: rowId,
        path: "/api/favorites",
        method: .post,
        statusCode: 201,
        body: "{\"ok\":true}",
        contentType: "application/json"
      )
    )
    let scenarios = KawarimiScenariosFile(scenarios: [
      KawarimiScenario(
        scenarioId: "favorite",
        initial: "add",
        cases: [
          .init(
            kawarimiId: "add",
            next: nil,
            rowId: rowId,
            endpoint: .init(method: "POST", path: "/api/favorites")
          ),
        ]
      ),
    ])
    try JSONEncoder().encode(scenarios).write(to: URL(fileURLWithPath: scenarioPath), options: .atomic)
    _ = await store.reloadFromDisk()

    let middleware = KawarimiServerMiddleware(store: store, responseMap: [:])
    var request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/favorites")
    request.headerFields[HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!] = "favorite"
    request.headerFields[HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!] = "add"

    let (response, _) = try await middleware.intercept(
      request,
      body: nil,
      metadata: ServerRequestMetadata(),
      operationID: "addFavorite",
      next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
    )
    #expect(response.status.code == 201)
    #expect(response.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] == nil)
  }
}

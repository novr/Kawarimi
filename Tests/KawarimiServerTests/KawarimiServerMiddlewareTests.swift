import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiServer

@Suite("KawarimiServerMiddleware")
struct KawarimiServerMiddlewareTests {
  @Test func returnsMockWithoutCallingNext() async throws {
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

  @Test func reloadFromDisk_appliesHandEditedConfig() async throws {
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
}

[日本語](README_JA.md) | English

# Kawarimi（代わり身）

A SwiftPM Build Tool Plugin that uses swift-openapi-generator to generate Types, Client, Server, Kawarimi (ClientTransport mock), and KawarimiHandler (APIProtocol default implementation) at build time.

## Usage

### 1. Add dependency and plugin

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.3.0"),
],
targets: [
    .target(
        name: "MyAPI",
        dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
        plugins: [.plugin(name: "KawarimiPlugin", package: "Kawarimi")]
    ),
]
```

### 2. Place OpenAPI spec

Put one openapi.yaml in the target’s source directory. The build generates Types.swift, Client.swift, Server.swift, Kawarimi.swift, and KawarimiHandler.swift.

### 3. Optional: config file

Place kawarimi.yaml (or openapi-generator-config.yaml) in the same directory to set generate, filter, featureFlags, and other swift-openapi-generator options.

### 4. Use mock in tests

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

## Dynamic Mock

Kawarimi generates `KawarimiSpec.swift` alongside the other files at build time. This file contains the full API spec (endpoints and response bodies) as Swift constants. Together with the server-side `MockInterceptorMiddleware` and Admin API, you can switch mock responses at runtime without recompiling.

### Generated file: KawarimiSpec.swift

`KawarimiSpec` is generated into your API target and exposes:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // all endpoints with their possible responses
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: (body, contentType)]
```

### Admin API (DemoServer / /__kawarimi/*)

When using `DemoServer` as a mock server, register the admin routes and middleware:

```swift
let store = MockConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "config.json")
registerAdminRoutes(app: app, store: store)
app.middleware.use(MockInterceptorMiddleware(store: store))
```

| Endpoint | Description |
|---|---|
| `POST /__kawarimi/configure` | Enable a mock response for a path/method/statusCode |
| `GET /__kawarimi/status` | List active overrides |
| `POST /__kawarimi/reset` | Clear all overrides |
| `GET /__kawarimi/spec` | Return the full KawarimiSpec (meta + endpoints) |

Example — enable a 200 mock for GET /api/greet:

```bash
curl -X POST http://localhost:8080/__kawarimi/configure \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":true}'
```

### DynamicMockTransport (client side)

`DynamicMockTransport` is a hand-written `ClientTransport` (generated into `DemoAPI`) that lets the client switch between the real server and the mock server at runtime:

```swift
let transport = DynamicMockTransport(
    underlying: URLSessionTransport(),
    realBaseURL: URL(string: "https://example.com/api")!,
    mockBaseURL: URL(string: "http://localhost:8080/api")!,
    useMockServer: true
)
let client = Client(serverURL: transport.mockBaseURL, transport: transport)
```

Set `x-kawarimi-mockId` header to target a specific named override:

```swift
transport.mockId = "error-case"
```

### config.json / KAWARIMI_CONFIG

`MockConfigStore` reads and writes overrides to a JSON file (default: `config.json` in the working directory). **Run DemoServer with the Example directory as the current working directory** so that `config.json` is read and written there (e.g. `cd Example && swift run DemoServer`). Set the `KAWARIMI_CONFIG` environment variable to override the path:

```bash
cd Example && swift run DemoServer   # config.json in Example/
KAWARIMI_CONFIG=/tmp/mock-config.json swift run DemoServer
```

### SwiftUI management UI (DemoAppUI)

Run `swift run DemoAppUI` to open a macOS window that shows all endpoints from the running server and lets you switch mock responses via a picker — no terminal required.

## Example

```bash
cd Example && swift build
swift run DemoServer   # in another terminal
swift run DemoApp      # client
swift run DemoAppUI    # SwiftUI management UI (optional)
```

## Requirements and details

- Swift 6.2+ / macOS 14+
- Supported: 200 + application/json operations, schemas referencing components/schemas via $ref
- See the repository for more.

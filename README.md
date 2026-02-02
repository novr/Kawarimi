[日本語](README_JA.md) | English

# Kawarimi（代わり身）

A SwiftPM Build Tool Plugin that uses swift-openapi-generator to generate Types, Client, Server, Kawarimi (ClientTransport mock), and KawarimiHandler (APIProtocol default implementation) at build time.

## Usage

### 1. Add dependency and plugin

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.2.0"),
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

## Example

```bash
cd Example && swift build
swift run DemoServer   # in another terminal
swift run DemoApp      # client
```

## Requirements and details

- Swift 6.2+ / macOS 14+
- Supported: 200 + application/json operations, schemas referencing components/schemas via $ref
- See the repository for more.

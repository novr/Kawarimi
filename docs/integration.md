# Integration

How to add Kawarimi to a Swift package alongside [swift-openapi-generator](https://github.com/apple/swift-openapi-generator).

## Patterns

### Simple

- One library target (e.g. `MyAPI`) with `openapi.yaml`, **OpenAPIGenerator**, and **KawarimiPlugin**. Build emits Types, Client, Server, and Kawarimi artifacts in that module.
- Client apps depend on `MyAPI` only; servers (e.g. Vapor) add Vapor and, for Henge, **KawarimiCore** and route wiring ([Example README](../Example/README.md)).
- **Pros:** smallest `Package.swift`, single config location. **Cons:** generated Server sources stay in the same module the app imports until you split targets.

### Recommended

- Keep **`openapi.yaml` as the single source of truth**, then use **separate generator setups** (targets and/or per-target `openapi-generator-config.yaml`) so the **client** builds **Types + Client** (and Kawarimi where needed) **without** shipping **Server** into the app, while the **server** builds **Types + Server**. Follow [swift-openapi-generator configuration](https://github.com/apple/swift-openapi-generator#configuration) so you do **not** duplicate Types in two modules.
- Attach **KawarimiPlugin** to the target that owns the canonical `openapi.yaml`.
- **Pros:** clearer boundaries. **Cons:** more moving parts; **CI should build both** client and server targets.

## 1. Dependencies and plugins

Upgrading from **0.11.x**? See **[CHANGELOG.md](../CHANGELOG.md)** for breaking changes and migration.

SwiftPM products from this package:

- **KawarimiCore** — runtime (`MockOverride`, `KawarimiConfigStore`, `KawarimiAPIClient`, …). No OpenAPIKit/Yams.
- **KawarimiJutsu** — generator API (`KawarimiJutsu.loadOpenAPISpec`, YAML config loaders, …). Pulls OpenAPIKit; for CLI/tests/custom tooling, not typical app binaries.
- **KawarimiHenge** — SwiftUI (`KawarimiConfigView`).

The target that hosts **KawarimiSpec.swift** must declare **`KawarimiCore`** and the **`HTTPTypes`** product as direct dependencies (same [swift-http-types](https://github.com/apple/swift-http-types) package). SwiftPM will not pick that up transitively from **KawarimiCore** alone.

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "1.0.2"),
],
targets: [
    .target(
        name: "MyAPI",
        dependencies: [
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "KawarimiCore", package: "Kawarimi"),
        ],
        plugins: [
            .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            .plugin(name: "KawarimiPlugin", package: "Kawarimi"),
        ]
    ),
]
```

For dynamic mock UI add **KawarimiHenge**; for `KawarimiAPIClient` add **KawarimiCore** — see [henge.md](henge.md).

## 2. OpenAPI spec location

Place one `openapi.yaml` in the **Swift target’s root directory** (the directory SwiftPM uses for that target — the same layout [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) expects). **KawarimiPlugin** resolves `openapi.yaml` from that root, not from an arbitrary source file’s folder. The build generates Types.swift, Client.swift, Server.swift (OpenAPIGenerator) and Kawarimi.swift, KawarimiHandler.swift, KawarimiSpec.swift (KawarimiPlugin).

## 3. Optional generator config

Add `openapi-generator-config.yaml` (or `.yml`) **next to `openapi.yaml`** for [swift-openapi-generator options](https://github.com/apple/swift-openapi-generator#configuration).

Kawarimi reads **`namingStrategy`** and **`accessModifier`** from that file.

Set **`handlerStubPolicy`** (`throw` / `fatalError`, default `throw`) in **`kawarimi-generator-config.yaml`** (or `.yml`) beside `openapi.yaml`.

The `Kawarimi` CLI and `KawarimiPlugin` look for `openapi-generator-config.yaml` then `openapi-generator-config.yml` next to `openapi.yaml`.

## 4. Use the mock in tests

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

<a id="requirements-and-tooling-notes"></a>

## Requirements and tooling notes

- Swift **6.2+** (matches `swift-tools-version` in `Package.swift`). **KawarimiPlugin** builds the `Kawarimi` tool with `-parse-as-library` (`unsafeFlags`); SwiftPM on **6.1** may **reject** that graph when depending on the plugin — use a 6.2 toolchain. CI uses [swift-actions/setup-swift](https://github.com/swift-actions/setup-swift) with **6.2**.
- The SwiftPM sample under **`Example/`** targets **macOS 14+**; Kawarimi library products also declare **iOS 17+** (`Package.swift` `platforms`).
- `handlerStubPolicy: throw` fails generation when a stub cannot be produced.
- `handlerStubPolicy: fatalError` keeps generation successful and traps at runtime for unsupported operations.

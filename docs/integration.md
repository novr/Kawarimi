# Integration

How to add Kawarimi to a Swift package alongside [swift-openapi-generator](https://github.com/apple/swift-openapi-generator).

## Patterns

### Simple

- One library target (e.g. `MyAPI`) with a single **`openapi.yaml` / `openapi.yml` / `openapi.json`**, **OpenAPIGenerator**, and **KawarimiPlugin**. Build emits Types, Client, Server, and Kawarimi artifacts in that module.
- Client apps depend on `MyAPI` only; servers (e.g. Vapor) add Vapor and, for Henge, **KawarimiCore** and route wiring ([Example README](../Example/README.md)).
- **Pros:** smallest `Package.swift`, single config location. **Cons:** generated Server sources stay in the same module the app imports until you split targets.

### Recommended

- Keep **one OpenAPI document per target** (`openapi.yaml`, `openapi.yml`, or `openapi.json`) as the single source of truth, then use **separate generator setups** (targets and/or per-target `openapi-generator-config.yaml`) so the **client** builds **Types + Client** (and Kawarimi where needed) **without** shipping **Server** into the app, while the **server** builds **Types + Server**. Follow [swift-openapi-generator configuration](https://github.com/apple/swift-openapi-generator#configuration) so you do **not** duplicate Types in two modules.
- Attach **KawarimiPlugin** to the target that owns that document.
- **Pros:** clearer boundaries. **Cons:** more moving parts; **CI should build both** client and server targets.

## 1. Dependencies and plugins

Upgrading from **0.11.x**? See **[CHANGELOG.md](../CHANGELOG.md)** for breaking changes and migration.

**1.0.x → 1.1.0:** **`OpenAPIPathPrefix`** was removed; use **`KawarimiPath`** (`splitPathSegments`, `joinPathPrefix`, `aligned(path:pathPrefix:)`) — see **[CHANGELOG.md](../CHANGELOG.md)** under **1.1.0**.

SwiftPM products from this package:

- **KawarimiCore** — runtime (`MockOverride`, `KawarimiConfigStore`, `KawarimiAPIClient`, …). No OpenAPIKit/Yams.
- **KawarimiJutsu** — generator API (`KawarimiJutsu.loadOpenAPISpec`, `OpenAPISpecDocumentURL`, YAML config loaders, …). Pulls OpenAPIKit; for CLI/tests/custom tooling, not typical app binaries.
- **KawarimiHenge** — SwiftUI (`KawarimiConfigView`). Henge **explorer state** (snapshot, draft, bootstrap, `isDirty` vs “Not saved”): [henge.md](henge.md#henge-explorer-state); lifecycle / list `.id`: [henge.md](henge.md#henge-ui-data-flow).

The target that hosts **KawarimiSpec.swift** must declare **`KawarimiCore`** and the **`HTTPTypes`** product as direct dependencies (same [swift-http-types](https://github.com/apple/swift-http-types) package). SwiftPM will not pick that up transitively from **KawarimiCore** alone.

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "1.1.2"),
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

In the **Swift target’s root directory** (the directory SwiftPM uses for that target — the same layout [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) expects), add **exactly one** OpenAPI document named **`openapi.yaml`**, **`openapi.yml`**, or **`openapi.json`**. Do not place more than one of these in the same target (the build fails if SwiftPM’s file list contains zero or several matches — same rule as OpenAPIGenerator’s `PluginUtils`).
**KawarimiPlugin** picks the document from **SwiftPM’s source file list** for that target (`SwiftSourceModuleTarget.sourceFiles`), not by scanning the directory independently.
The build generates Types.swift, Client.swift, Server.swift (OpenAPIGenerator) and Kawarimi.swift, KawarimiHandler.swift, KawarimiSpec.swift (KawarimiPlugin).

## 3. Optional generator config

Add `openapi-generator-config.yaml` (or `.yml`) **in the target root next to your OpenAPI document** for [swift-openapi-generator options](https://github.com/apple/swift-openapi-generator#configuration).

Kawarimi reads **`namingStrategy`** and **`accessModifier`** from that file.

Set **`handlerStubPolicy`** (`throw` / `fatalError`, default `throw`) in **`kawarimi-generator-config.yaml`** (or `.yml`) in that same directory.

The `Kawarimi` CLI and `KawarimiPlugin` look for `openapi-generator-config.yaml` then `openapi-generator-config.yml` next to the resolved OpenAPI file (same directory as the spec).

## 4. Use the mock in tests

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

<a id="requirements-and-tooling-notes"></a>

## Requirements and tooling notes

- Swift **6.2+** (matches `swift-tools-version` in `Package.swift`). **KawarimiPlugin** builds the `Kawarimi` tool with `-parse-as-library` (`unsafeFlags`); SwiftPM on **6.1** may **reject** that graph when depending on the plugin — use a 6.2 toolchain. CI uses [swift-actions/setup-swift](https://github.com/swift-actions/setup-swift) with **6.2**.
- The SwiftPM sample under **`Example/`** targets **macOS 14+**; Kawarimi library products also declare **iOS 17+** (`Package.swift` `platforms`).
- `handlerStubPolicy: throw` fails generation when **any** operation cannot get a default `KawarimiHandler` stub.
  For example: documented success is not stubbable **HTTP 200 / 201** with `application/json` or an empty body, nor **HTTP 204**, or the generator cannot synthesize headers-only responses.
- `handlerStubPolicy: fatalError` keeps generation successful; operations that **still** cannot be stubbed emit a `fatalError()` closure body at runtime (stderr warns with their `operationId`s).
  JSON success responses use a literal initializer when possible, otherwise the **JSON decode fallback** described in [mock-json.md](mock-json.md#kawarimihandler-default-stubs).

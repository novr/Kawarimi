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

Upgrading? See **[CHANGELOG.md](../CHANGELOG.md)**.

**2.0.5 → 2.1.0** (additive):

1. Bump pin to **`from: "2.1.0"`**.
2. Server: **KawarimiServer** + **`KawarimiServerMiddleware`** in **`registerHandlers(middlewares:)`** — [henge.md](henge.md), [Example/README.md](../Example/README.md).
3. Drop the old Vapor-global interceptor pattern for operation mocks if copied from Example.
4. Rebuild after OpenAPI regen so **`responseMap`** matches **`KawarimiSpec`**.

**2.1.0 → 2.2.0** (additive):

1. Bump pin to **`from: "2.2.0"`**.
2. Optional **`delayMs`** on overrides; optional **`POST …/__kawarimi/reload`** / **`KawarimiConfigStore.reloadFromDisk()`**.
3. Custom Henge UI: **`primaryEnabledOverrideForOperation`** / **`matchingEnabledOverridesForOperation`** ([#78](https://github.com/novr/Kawarimi/issues/78)).

**2.2.2 → 2.3.0** (additive):

1. Bump pin to **`from: "2.3.0"`**.
2. Regenerate **`KawarimiSpec.swift`** when using **`SpecEndpointProviding`** or **`SpecResponse`** — endpoints expose optional **`security`**; **`GET …/__kawarimi/spec`** includes **`securitySchemes`** when defined ([#102](https://github.com/novr/Kawarimi/pull/102)).
3. **Henge** displays **`securitySchemes`** and per-endpoint effective **`security`** read-only in the detail column ([#108](https://github.com/novr/Kawarimi/issues/108)); oauth2 flow URLs are not expanded yet.
4. Client-only or in-process **`Kawarimi()`** users need no change unless they use the spec endpoint or generated **`KawarimiSpec`** shape. See **[CHANGELOG.md](../CHANGELOG.md)** under **2.3.0**.

SwiftPM products:

- **KawarimiCore** — runtime (`MockOverride`, `KawarimiConfigStore`, `KawarimiAPIClient`, …).
- **KawarimiJutsu** — generator API (CLI/tests; OpenAPIKit).
- **KawarimiHenge** — SwiftUI admin — [henge.md](henge.md).
- **KawarimiServer** — server dynamic mocks — [henge.md](henge.md).

Targets with **KawarimiSpec.swift** need **`KawarimiCore`** and **`HTTPTypes`** as **direct** dependencies.

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "2.3.0"),
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

For dynamic mock UI add **KawarimiHenge**; for `KawarimiAPIClient` add **KawarimiCore**; for server-side runtime overrides add **KawarimiServer** — see [henge.md](henge.md).

## 2. OpenAPI spec location

In the **Swift target root** (same layout as [swift-openapi-generator](https://github.com/apple/swift-openapi-generator)), add **exactly one** of **`openapi.yaml`**, **`openapi.yml`**, or **`openapi.json`**. **KawarimiPlugin** picks it from **`sourceFiles`**, not by directory scan. Build output: Types/Client/Server (OpenAPIGenerator) and Kawarimi/KawarimiHandler/KawarimiSpec (KawarimiPlugin).

## 3. Generator config (required)

**Exactly one** **`openapi-generator-config.yaml`** or **`.yml`** beside the OpenAPI document ([swift-openapi-generator configuration](https://github.com/apple/swift-openapi-generator#configuration)). Kawarimi reads **`namingStrategy`** and **`accessModifier`**.

Optional **`kawarimi-generator-config.yaml`** (at most one): **`handlerStubPolicy`** (`throw` / `fatalError`), **`generateKawarimi`**, **`generateHandler`**, **`generateSpec`** (default **`true`**; at least one must stay enabled). Plugin: **`sourceFiles`**; CLI: directory of the spec path.

Regenerate **`KawarimiSpec.swift`** when using **`SpecEndpointProviding`** after upgrades. Endpoints expose optional OpenAPI **`tags`** (`nil` when absent). Request parameters: [#74](https://github.com/novr/Kawarimi/issues/74).

## 4. Use the mock in tests

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

<a id="requirements-and-tooling-notes"></a>

## Requirements and tooling notes

- Swift **6.2+** (`Package.swift`). **KawarimiPlugin** uses `-parse-as-library` (`unsafeFlags`); **6.1** SwiftPM may reject the graph.
- **`Example/`**: macOS 14+; library products also **iOS 17+**.
- **`handlerStubPolicy`**: `throw` fails generation if any operation lacks a default handler stub; `fatalError` keeps generation and fails at runtime for those operations ([mock-json.md](mock-json.md#kawarimihandler-default-stubs)).

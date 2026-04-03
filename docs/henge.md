# Dynamic mock (KawarimiHenge)

**Build time:** the **Kawarimi** plugin generates `KawarimiSpec.swift` with endpoints and response bodies as Swift constants.

**Runtime** mock switching — overrides without recompiling — is a **KawarimiHenge** feature.

Add **KawarimiCore** for `KawarimiAPIClient` (HTTP to `{pathPrefix}/__kawarimi/*`) and **KawarimiHenge** for SwiftUI (`KawarimiConfigView`).

On the server, use **KawarimiCore** (`KawarimiConfigStore`, `PathTemplate`, `MockOverride`, …) and register the **Henge API** routes. **Vapor `AsyncMiddleware` that applies overrides is not a KawarimiCore product** — copy or adapt the reference [`KawarimiInterceptorMiddleware.swift`](../Example/DemoPackage/Sources/DemoServer/KawarimiInterceptorMiddleware.swift) (see [Example README](../Example/README.md)).

## Vapor-related packages (server)

Kawarimi does not ship a Vapor product; combine your generated API target with the usual OpenAPI + Vapor stack:

| Piece | Link / notes |
| --- | --- |
| Web framework | [github.com/vapor/vapor](https://github.com/vapor/vapor) |
| Generated server ↔ Vapor | [github.com/vapor/swift-openapi-vapor](https://github.com/vapor/swift-openapi-vapor) (`OpenAPIVapor`) |
| Runtime for generated code | [github.com/apple/swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) |
| OpenAPI code generation | [github.com/apple/swift-openapi-generator](https://github.com/apple/swift-openapi-generator) |
| Henge file store + matching | **KawarimiCore** (this package) |

`DemoPackage` layout and `DemoServer` entrypoints: [Example/README.md](../Example/README.md).

## Generated file: `KawarimiSpec.swift`

`KawarimiSpec` is generated into your API target and exposes:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // all endpoints with their possible responses
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: [exampleId: (body, contentType)]]
```

OpenAPI **named** `content.examples` keys become `exampleId` strings in `endpoints` and as the inner `responseMap` keys.

A single unnamed example (or schema-only fallback) is stored under the reserved key **`__default`**.

At runtime, `MockOverride.exampleId` of `nil`, JSON `null`, or empty string selects **`__default`** for lookup.

The JSON file does not store the literal `__default` for “default example” — omit the field or use `null`.

### Reserved: `__default`

The string **`__default` is reserved by Kawarimi** for:

- The inner `responseMap` key for the **synthetic default row** (no named OpenAPI `examples`, or non‑JSON / fallback paths that still emit one body).
- **Lookup** when `MockOverride.exampleId` is omitted, JSON `null`, or empty (whitespace‑only is normalized away).

**Do not use `__default` as a key in OpenAPI `content.examples`.** Use another name (e.g. `default` or `success`) so your contract does not collide with this reserved slot. An override may still set `exampleId` to the literal `"__default"` to target that map entry explicitly; the usual pattern is to omit `exampleId` for the default example.

`KawarimiConfigStore.configure` treats overrides as distinct when **`path`, HTTP method, `statusCode`, and normalized `exampleId`** match.

`configure` **upserts** one row: set `isEnabled: false` to turn a mock off while **keeping** that row in `kawarimi.json`. **`KawarimiConfigStore.removeOverride`** deletes the first row with the **same identity** (after the same normalization as `configure`). Calling `removeOverride` when nothing matches is a **no-op** (idempotent).

Two enabled overrides for the same path/method but different examples are distinguished by `exampleId`.

For how mock JSON strings are chosen, see [mock-json.md](mock-json.md).

## Henge API (`{pathPrefix}/__kawarimi/*`)

**Henge API** is the HTTP surface that **`KawarimiAPIClient`** (in **KawarimiCore**) talks to (the name “Henge” is the feature).

Mount admin routes **under a path prefix aligned with your OpenAPI API** (e.g. **`/api/__kawarimi/spec`** when the API lives under `/api`). You may mount `__kawarimi` at the root in your own app; keep it aligned with `KawarimiAPIClient`’s `baseURL`.

Register the admin routes and middleware in Vapor, for example:

```swift
let store = try KawarimiConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "kawarimi.json")
registerKawarimiRoutes(app: app, store: store)
app.middleware.use(KawarimiInterceptorMiddleware(store: store))
```

`KawarimiInterceptorMiddleware` lives in the **Example** target, not in the library.

It implements Vapor’s `AsyncMiddleware` by:

- Skipping `__kawarimi` admin paths.
- Matching enabled overrides (path template, method).
- Resolving the body from the override or from `KawarimiSpec.responseMap` using **`statusCode` plus the effective example key** (`exampleId` → `__default` when unset).
- Returning a synthetic `Response` or calling `next`.

Use that file as the **authoritative sample** when writing your own middleware.

### Optional request header: `X-Kawarimi-Example-Id`

For **per-request** disambiguation (not `configure` JSON), the Example middleware reads **`X-Kawarimi-Example-Id`**. Header name is **`KawarimiMockRequestHeaders.exampleId`** in **KawarimiCore**.

When **several enabled overrides** match the same path and method, a non-empty header **narrows** candidates to overrides whose effective example map key matches (same rules as ``KawarimiExampleIds/responseMapLookupKey(forOverrideExampleId:)`` — e.g. `success` matches an override with `exampleId` `"success"`; use `__default` to target the default example row). If narrowing would match **no** overrides, the middleware **ignores** the header and uses all candidates (then tie-break as usual).

Omit the header or send whitespace-only to apply **no** narrowing.

| Endpoint | Description |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | Upsert an override for a path/method/statusCode (and optional `exampleId`). Set `isEnabled` / `body` / `contentType` as needed. |
| `POST {pathPrefix}/__kawarimi/remove` | Remove one override row that matches the same identity as `configure` (normalized path, method, `statusCode`, `exampleId`). Idempotent. |
| `GET {pathPrefix}/__kawarimi/status` | List active overrides |
| `POST {pathPrefix}/__kawarimi/reset` | Clear all overrides |
| `GET {pathPrefix}/__kawarimi/spec` | Return the full KawarimiSpec (meta + endpoints) |

**KawarimiHenge (`KawarimiConfigView`):** the minus (**Del**) control persists **`isEnabled: false`** for the current response chip when the mock is on. When the mock is **already off** and a **saved** row exists for that chip, **Del** calls **`remove`** so the row is dropped from the server config and the editor returns to the spec draft. Integrators must pass **`removeOverride`** into `KawarimiConfigView` (see **`KawarimiAPIClient.removeOverride(override:)`** in **KawarimiCore**).

Sample **`curl`** for this repository’s **DemoServer**: [Example/README.md#try-the-henge-api-demoserver](../Example/README.md#try-the-henge-api-demoserver).

## Override editor (`OverrideEditorView`)

The SwiftUI mock UI is **`OverrideEditorView`** in **KawarimiHenge** (endpoint explorer + detail column). **Editing rules** (response chips, Save payload shape, Del branching, endpoint search) live under **`Sources/KawarimiHenge/EditorSupport/`** — e.g. `ResponseChips`, `SavePayload`, `DisableMockPlanner`, `EndpointFilter`. **Which row is selected** and draft metadata (`validationMessage`, `isDirty`) are owned by **`OverrideEditorStore`** / **`OverrideDetailDraft`**.

| UI / doc term | Code | Notes |
| --- | --- | --- |
| Endpoint list row | `EndpointRowKey` + `SpecEndpointItem` | Selection is by `EndpointRowKey`. |
| Detail editor | One `MockOverride` in `OverrideDetailDraft` | A snapshot for the selected logical row, not the entire overrides array. |
| Server / config row | `MockOverride` in `kawarimi.json` | Same identity as configure/remove: **`path` + `method` + `statusCode` + normalized `exampleId`**. Do not describe deletes as “by `operationId` only”. |
| Default / unnamed example | `exampleId` nil (after trim) | Aligns with reserved **`__default`** at lookup time; UI treats it as “no example id”. |

**Spec** response chip is selected when the draft mock is **disabled** and **no stored row** matches the current `statusCode` and `exampleId` (so disabled-but-persisted rows stay on their chip, not Spec).

**Save** calls `configure` with **`SavePayload`**: the override is sent as enabled if the mock toggle is on, or a stored row exists for that status/example, or the response is **not** listed in the OpenAPI operation (custom status/example). If the payload is disabled for a spec-only choice, **`statusCode`** is the operation’s first spec status, **`exampleId`** is cleared, and body fields are cleared for the wire.

**Del** uses **`DisableMockPlanner`**: active mock → `configure` with `isEnabled: false` (same keys); already off with a matching stored row → **`remove`** then reset the draft toward the spec default; otherwise **no-op**.

**Automated tests:** target **`KawarimiHengeTests`** (`Tests/KawarimiHengeTests/`) exercises filter, chip transitions, save payload, and Del planning.

## Client: real server vs Kawarimi mock

Use **two** generated `Client` instances if you want both in-process mocks and a live server:

- `Kawarimi()` — no network; responses use the rules in [mock-json.md](mock-json.md) (per-operation 200 + `application/json`).
- `URLSessionTransport()` from [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) against your HTTP server (add that product to your target).

`KawarimiSpec` (and Henge / `responseMap`) is **not** filled by the same generator pass as the in-process `Kawarimi` transport; see **`KawarimiSpec` vs in-process `Kawarimi` transport** in [mock-json.md](mock-json.md).

This repository includes **DemoServer** and **DemoApp** under **`Example/`** — see [Example/README.md](../Example/README.md).

If you need **one** client that switches real vs mock at runtime, implement a small `ClientTransport` wrapper in your app that forwards to `URLSessionTransport` and picks `baseURL` / headers.

<a id="kawarimijson--kawarimi_config"></a>

## `kawarimi.json` / `KAWARIMI_CONFIG`

`KawarimiConfigStore` (**KawarimiCore**) reads and writes overrides to a JSON file (default: `kawarimi.json` in the working directory).

The file format uses `KawarimiConfig` (overrides array).

Set `KAWARIMI_CONFIG` to override the config file path.

`kawarimi.json` holds runtime `overrides` only; use `kawarimi-generator-config.yaml` for `handlerStubPolicy`.

Starter **`kawarimi.json`**, sample **`kawarimi-generator-config.yaml`**, and **`swift run DemoServer` working-directory notes** for this repository: [Example/README.md](../Example/README.md).

Empty-string `body` / `contentType` on an override is normalized to “not set” when saved; at response time, an empty body falls back to the spec response.

If several overrides match the same request (same path template + method), the interceptor **sorts** by `MockOverride.sortedForInterceptorTieBreak` and uses the **first** entry.

Comparison order: `path`, then `statusCode`, then `name`, then `exampleId`.

Equal keys keep **`hits` order** (Swift stable `sort`). A warning is still logged with that order.

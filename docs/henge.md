# Dynamic mock (KawarimiHenge)

**Build time:** the **Kawarimi** plugin generates `KawarimiSpec.swift` with endpoints and response bodies as Swift constants.

**Runtime** mock switching — overrides without recompiling — is a **KawarimiHenge** feature.

Add **KawarimiCore** for `KawarimiAPIClient` (HTTP to `{pathPrefix}/__kawarimi/*`) and **KawarimiHenge** for SwiftUI (`KawarimiConfigView`).

On the server, use **KawarimiCore** (`KawarimiConfigStore`, `MockOverride`, …), **KawarimiServer** (`KawarimiServerMiddleware`), and register the **Henge API** routes.

Apply dynamic mocks on OpenAPI-registered operations via **`KawarimiServerMiddleware`** (`registerHandlers(middlewares:)`). Vapor global `AsyncMiddleware` is optional when you need overrides on paths **not** registered on the handler (see below).

## Vapor-related packages (server)

Kawarimi does not ship a Vapor product; combine your generated API target with the usual OpenAPI + Vapor stack:

| Piece | Link / notes |
| --- | --- |
| Web framework | [github.com/vapor/vapor](https://github.com/vapor/vapor) |
| Generated server ↔ Vapor | [github.com/vapor/swift-openapi-vapor](https://github.com/vapor/swift-openapi-vapor) (`OpenAPIVapor`) |
| Runtime for generated code | [github.com/apple/swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) |
| OpenAPI code generation | [github.com/apple/swift-openapi-generator](https://github.com/apple/swift-openapi-generator) |
| Henge file store + matching | **KawarimiCore** (this package) |
| Dynamic mock on server operations | **KawarimiServer** (`KawarimiServerMiddleware`) |
| Henge admin HTTP (`__kawarimi/*`) | **KawarimiServer** (`KawarimiAdminHTTPHandler`; admin is outside OpenAPI registration) |
| Scenario orchestration on OpenAPI client | **KawarimiClient** (`KawarimiClientOrchestrationMiddleware`) |

`DemoPackage` layout and `DemoServer` entrypoints: [Example/README.md](../Example/README.md).

<a id="hengecli-macos"></a>

## HengeCli (macOS sample app)

**`Example/DemoPackage`** defines an executable product **`HengeCli`**.

It is a **macOS-only** SwiftUI app that embeds **`KawarimiConfigView(client: KawarimiAPIClient(baseURL: …))`**. The admin **`baseURL`** defaults to `http://127.0.0.1:8080/api` (Demo **`openapi.yaml`** `servers`) and can be overridden with **`KAWARIMI_BASE_URL`** — see **`DemoSupport`** / `KawarimiDemoClientURL.swift` (shared with **DemoApp**).

- **Run:** from `Example/DemoPackage`, `swift run HengeCli` (or `swift build --product HengeCli`).  
  Start **`DemoServer`** (or any server that serves **`…/__kawarimi/*`** under that base URL) first.

- **Window lifecycle:** closing the **last window quits** the process (`applicationShouldTerminateAfterLastWindowClosed`).

  On launch, **`NSApp.activate(ignoringOtherApps: true)`** and **`makeKeyAndOrderFront`** run so the window is key when launched from Terminal or other non-GUI parents (text fields and editors accept input reliably).

- **Bad base URL:** if **`KAWARIMI_BASE_URL`** (or the default) is not a valid URL, the UI shows **`ContentUnavailableView`** with a hint to set the env var or use the default.

iOS and other platforms compile a **stub** `main` that exits with an error message.

Use **`DemoApp`** or your own target for those platforms.

Detail-column layout regression (DemoApp Preview + manual checks): [henge-detail-column-regression.md](henge-detail-column-regression.md).

## Generated file: `KawarimiSpec.swift`

`KawarimiSpec` is generated into your API target and exposes:

```swift
KawarimiSpec.meta             // title, version, serverURL
KawarimiSpec.securitySchemes  // components.securitySchemes catalog (nil when empty)
KawarimiSpec.endpoints        // operations; each may include effective security
KawarimiSpec.responseMap      // "METHOD:/path" → [statusCode: [exampleId: (body, contentType)]]
```

Each **`Endpoint.security`** is the **effective** OpenAPI security for that operation (global `security` inherited when the operation omits it; `security: []` means none). The `security` array is a list of **OR** alternatives; each `SecurityRequirement.schemes` entry is an **AND** group. For apiKey schemes, use `SecurityScheme.apiKeyName` for the HTTP header/query/cookie name; for `http` use `httpScheme` / `bearerFormat`; for openIdConnect use `openIdConnectURL`. OAuth2 flow URLs and scopes are not emitted. `ScopedSecurityScheme.name` is the components key.

The generated **`SpecResponse`** type conforms to **`KawarimiFetchedSpec`** and also carries **`securitySchemes`** for the Henge wire JSON (`GET …/__kawarimi/spec`). Host code that still links a generated API module can decode the same wire JSON with **`KawarimiAPIClient.fetchSpec(as: SpecResponse.self)`**.

**Henge UI** uses **`KawarimiConfigView(client:)`** only: spec and endpoints come from **`GET …/__kawarimi/spec`** via Core **`HengeSpecSnapshot`** / **`fetchHengeSpec()`** — no generated **`SpecResponse`** in the Henge-only app target.

OpenAPI **named** `content.examples` keys become `exampleId` strings in `endpoints` and as the inner `responseMap` keys.

A single unnamed example (or schema-only fallback) is stored under the reserved key **`__default`**.

At runtime, `MockOverride.exampleId` of `nil`, JSON `null`, or empty string selects **`__default`** for lookup.

The JSON file does not store the literal `__default` for “default example” — omit the field or use `null`.

### Reserved: `__default`

The string **`__default` is reserved by Kawarimi** for:

- The inner `responseMap` key for the **synthetic default row** (no named OpenAPI `examples`, or non‑JSON / fallback paths that still emit one body).
- **Lookup** when `MockOverride.exampleId` is omitted, JSON `null`, or empty (whitespace‑only is normalized away).

**Do not use `__default` as a key in OpenAPI `content.examples`.** Use another name (e.g. `default` or `success`) so your contract does not collide with this reserved slot.

An override may still set `exampleId` to the literal `"__default"` to target that map entry explicitly; the usual pattern is to omit `exampleId` for the default example.

`KawarimiConfigStore.configure` matches rows in this order:

1. **`rowId` match first** (UUID string, case-insensitive after normalization).
2. **Legacy fallback** only when the **incoming row has no `rowId`**: `path` + HTTP method + `statusCode` + normalized `exampleId`.
3. If several legacy rows still qualify, the **first row wins** (stable, deterministic).

`configure` **upserts** one row: set `isEnabled: false` to turn a mock off while **keeping** that row in `kawarimi.json`.

**`KawarimiConfigStore.removeOverride`** uses the same identity order as `configure` (`rowId` first, then legacy fallback for nil `rowId` rows). Calling `removeOverride` when nothing matches is a **no-op** (idempotent).

Two enabled overrides for the same path/method but different examples are distinguished by `exampleId`.

For how mock JSON strings are chosen, see [mock-json.md](mock-json.md).

## Henge API (`{pathPrefix}/__kawarimi/*`)

**Henge API** is the HTTP surface that **`KawarimiAPIClient`** (in **KawarimiCore**) talks to (the name “Henge” is the feature).

Mount admin routes **under a path prefix aligned with your OpenAPI API** (e.g. **`/api/__kawarimi/spec`** when the API lives under `/api`).

You may mount `__kawarimi` at the root in your own app; keep it aligned with `KawarimiAPIClient`’s `baseURL`.

### Core admin route contract

**KawarimiCore** exposes the shared HTTP contract so clients and servers stay aligned without duplicating path strings:

- **`KawarimiAdminRoute`** — `spec`, `status`, `configure`, `remove`, `reset`, `reload`; each case provides **`httpMethod`**, **`relativePath`**, and **`successStatusCode`** (`200`).
- **`KawarimiAdminRoute.adminURL(baseURL:route:)`** — builds `{baseURL}/__kawarimi/{segment}` (same rules as **`KawarimiAPIClient`**).
- **`KawarimiAdminRoute.matching(requestPath:method:pathPrefix:)`** — same path rules as **`adminURL`** / **`KawarimiAPIClient`** on the server side.
- **`KawarimiAdminSpecWire.validate(_:)`** — fail-fast decode check that encoded spec wire JSON matches **`HengeSpecSnapshot`** (`GET …/spec` contract). Call after **`JSONEncoder`** on your host **`SpecResponse`** (or equivalent) at startup; **`KawarimiAdminHeaders.jsonContentType`** is the shared JSON **`Content-Type`** string.

Wire **`KawarimiAdminHTTPHandler`** (product **KawarimiServer**) into your HTTP stack, then attach **`KawarimiServerMiddleware`** when registering generated handlers. On Vapor, see **DemoServer** ([`KawarimiAdminVaporMiddleware.swift`](../Example/DemoPackage/Sources/DemoServer/KawarimiAdminVaporMiddleware.swift)):

```swift
let store = try KawarimiConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "kawarimi.json")
let adminHandler = KawarimiAdminHTTPHandler(
    store: store,
    specWireData: { try SpecResponse.encodedWireData() } // host equivalent
)
app.middleware.use(KawarimiAdminVaporMiddleware(handler: adminHandler))
let transport = VaporTransport(routesBuilder: app)
try handler.registerHandlers(
    on: transport,
    serverURL: serverURL,
    middlewares: [KawarimiServerMiddleware(store: store, responseMap: KawarimiSpec.responseMap)]
)
```

**`KawarimiAdminHTTPHandler`** returns `nil` for non-admin traffic so the host stack can still route normal API requests. It is not **`ServerMiddleware`** — `__kawarimi` is never registered as an OpenAPI operation.

**`KawarimiServerMiddleware`** (product **KawarimiServer**) conforms to swift-openapi-runtime’s **`ServerMiddleware`**. It:

- Matches enabled overrides (path template or `operationId` via `MockOverride.name`, HTTP method).
- Resolves the body from the override or from `KawarimiSpec.responseMap` using **`statusCode` plus the effective example key** (`exampleId` → `__default` when unset).
- Returns a synthetic HTTP response **without** calling `next` when a mock applies.
- When **`KAWARIMI_UPSTREAM_URL`** is set and no override matches, forwards the raw HTTP request to upstream **without** calling `next` (see [Proxy](#proxy-upstream-forward) below).
- Otherwise delegates to the generated handler (`next` → OpenAPI stubs).

**In-process `Kawarimi` (`ClientTransport`) does not read `kawarimi.json` or apply runtime overrides** — only the server middleware path above (or your own integration) does.

<a id="proxy-upstream-forward"></a>

## Proxy (upstream forward)

**Proxy** is the Kawarimi runtime sidecar (e.g. **DemoServer** + Henge admin + `KawarimiServerMiddleware` + `kawarimi.json`). Behavior is a **spectrum** driven by enabled overrides and whether upstream is configured — not separate “direct / proxy / full mock” product modes.

| Situation | What you do | Result |
| --- | --- | --- |
| **Direct** | Do not run Proxy; point the app at the real API | Kawarimi runtime not in the request path |
| **Proxy, upstream set, 0 overrides** | Run Proxy; set `KAWARIMI_UPSTREAM_URL` | All registered operations forward to upstream |
| **Proxy, partial overrides** | Enable overrides for some operations | Matched → mock; others → upstream (when upstream set) |
| **Full mock equivalent** | Enable overrides for all operations you care about | Upstream receives nothing for those routes |

When **`KAWARIMI_UPSTREAM_URL` is unset**, override misses behave as today: **`next`** → generated OpenAPI stubs. No new response headers; existing E2E behavior is unchanged.

### Forward implementation

Upstream passthrough is implemented in **`KawarimiServerMiddleware`** via **`KawarimiUpstreamHTTPForwarder`** (raw HTTP, not generated `KawarimiHandler` / Client). **`__kawarimi/*`** stays on **`KawarimiAdminHTTPHandler`** and is never forwarded.

On forward, hop-by-hop headers (`Host`, `Connection`, …) and Kawarimi control headers (`X-Kawarimi-*`, `X-Next-Kawarimi-*`) are dropped; other request headers pass through. `Content-Length` is omitted when a body is forwarded so the outbound client can set it. Cookie-based session auth through Proxy is **out of scope** for v1 (use Bearer tokens).

`URLSession` follows redirects by default. Request bodies stream to upstream via temp file → `httpBodyStream` (max **10 MiB**). Responses stream on macOS and Linux via `URLSession.bytes(for:)` `AsyncBytes` into `HTTPBody` in 16 KiB chunks (max **10 MiB**; overflow → `502`).

`URLSession` is an **implementation detail** (`KawarimiProxyURLSessionTransport.live()`) and is not replaceable through the public API. Delegates are fixed at session creation; allowing injection would silently break streamed forwarding.

Path forwarding uses **`KawarimiPath.aligned`** with `apiPathPrefix` (re-apply prefix when missing; **do not strip** an existing prefix).

| URL | Form |
| --- | --- |
| `KAWARIMI_BASE_URL` | `{proxy-origin}{apiPathPrefix}` — Henge / app → Proxy |
| `KAWARIMI_UPSTREAM_URL` | **Origin only** — e.g. `https://staging.example.com` (no `/api` path; aligned at forward time) |

### Environment variables (Proxy)

| Variable | Required | Purpose |
| --- | --- | --- |
| `KAWARIMI_UPSTREAM_URL` | No | When set, enables upstream forward on override miss. Origin only. |
| `KAWARIMI_BASE_URL` | No | Proxy URL for Henge / clients (includes `apiPathPrefix`). |
| `KAWARIMI_UPSTREAM_STRICT` | No | `1` → fail startup if upstream URL includes a path component. |
| `KAWARIMI_PROXY_DEBUG` | No | Extra `KawarimiProxy` OSLog when upstream is set. |

When upstream is set, responses may include **`X-Kawarimi-Proxy-Action: mock`** or **`forward`**. This header is **not** added when upstream is unset.

**Out of scope (v1):** Client-side middleware switching (app → upstream directly with in-process overrides), catch-all forward for unregistered paths, path remapping, Cookie rewrite, admin auth.

### Override matching product rules

The **single source of truth for matching and primary selection** is **KawarimiCore** (`MockOverrideRequestMatching`, `MockOverride.sortedForOverrideTieBreak`). Henge explorer and `KawarimiServerMiddleware` call the same APIs; this section is the user-facing contract.

1. **Operation identity** — When `MockOverride.name` and the OpenAPI `operationId` are both non-empty and equal, the override matches that operation **without comparing path** (hand-edited `path` typos still match by id). This is intentional, not a bug.
2. **Path binding** — When identity does not decide:
   - **Incoming HTTP (server):** Compare the request URL (path only) to the persisted override `path` using `PathTemplate` + `pathPrefix` (`overrideMatchesIncomingRequest`).
   - **Explorer row (Henge):** Compare the spec / row template path to the persisted `path` using `KawarimiPath.aligned` (`overrideMatchesOperation`).
3. **Primary selection** — Among **enabled** overrides that match the same operation, the **first** after `sortedForOverrideTieBreak` wins (`path` → `statusCode` → `name` → `exampleId`; stable sort preserves `hits` order for equal keys). **`X-Kawarimi-Example-Id`** narrows candidates only on **incoming** requests (`matchingEnabledOverrides`); the explorer does not send this header.
4. **Non-goals** — In-process `Kawarimi` (`ClientTransport`) does not apply runtime overrides (#75).

API summary:

| Context | Match | Primary / list |
| --- | --- | --- |
| Server (`KawarimiServerMiddleware`) | `matchingEnabledOverrides` / `primaryEnabledOverride` | Incoming path + optional example header |
| Henge explorer | `matchingEnabledOverridesForOperation` / `primaryEnabledOverrideForOperation` | Spec row path + `operationId` |

`sortedForInterceptorTieBreak` remains as an alias of `sortedForOverrideTieBreak`.

### Runtime updates

| What | Behavior |
| --- | --- |
| **Overrides (`kawarimi.json`)** | Updated when Henge / `KawarimiAPIClient` calls `POST …/configure`, when **`POST …/reload`** re-reads the file, or when **`KawarimiConfigStore/startFileWatchIfEnabled()`** is active (default for **DemoServer**): saving `kawarimi.json` on disk reloads into memory. Disable watch with **`KAWARIMI_CONFIG_WATCH=0`**. Reload / watch use the **same load rules as startup** (invalid JSON → empty overrides). Disk loads still skip full `configure` normalization, but `rowId` is normalized (trim + lowercase UUID validation) during load. Within a single server process, the last completed `configure` / `reload` / `reset` / disk reload wins. |
| **Scenarios (`kawarimi-scenarios.json`)** | Read-only at runtime (no Henge admin API). Loaded with overrides on startup, **`POST …/reload`**, and file watch when enabled. Path: init `scenariosPath:` → **`KAWARIMI_SCENARIOS_CONFIG`** → `{kawarimi.json directory}/kawarimi-scenarios.json`. Invalid JSON → empty scenarios; structural issues log **warnings** via **`KawarimiScenarioValidation`**. Saving an **existing** scenarios file via atomic replace may not trigger vnode watch on macOS — use **`POST …/reload`** if edits do not apply. |
| **`KawarimiSpec` / `responseMap`** | **Build-time** from OpenAPI (not `kawarimi.json`). Fixed at **`KawarimiServerMiddleware` init**. After OpenAPI regen, **rebuild and restart** (or re-register middleware). **`POST …/reload` does not update spec bodies.** |

### Optional: Vapor global middleware

If you need dynamic mocks on **unregistered** paths (not covered by `registerHandlers`), you can still implement Vapor `AsyncMiddleware` using **`MockOverrideRequestMatching`** and **`KawarimiDynamicMockResponseResolver`** from **KawarimiCore** (see [Example/README.md](../Example/README.md) for the previous pattern).

### Optional request header: `X-Kawarimi-Example-Id`

For **per-request** disambiguation (not `configure` JSON), **`KawarimiServerMiddleware`** reads **`X-Kawarimi-Example-Id`**.

The header name in code is **`KawarimiMockRequestHeaders.exampleId`** in **KawarimiCore**.

When **several enabled overrides** match the same path and method, a non-empty header **narrows** candidates to overrides whose effective example map key matches (same rules as ``KawarimiExampleIds/responseMapLookupKey(forOverrideExampleId:)`` — e.g. `success` matches an override with `exampleId` `"success"`; use `__default` to target the default example row).

If narrowing would match **no** overrides, the middleware **ignores** the header and uses all candidates (then tie-break as usual).

Omit the header or send whitespace-only to apply **no** narrowing.

### Scenario orchestration (`kawarimi-scenarios.json`)

**Multi-step flows** reuse existing **`MockOverride`** rows for response bodies. Scenario definitions live in **`kawarimi-scenarios.json`** (separate from `kawarimi.json`). Override path with init **`scenariosPath:`** or **`KAWARIMI_SCENARIOS_CONFIG`**.

`POST …/__kawarimi/reload` and file watch reload **both** `kawarimi.json` and `kawarimi-scenarios.json`. **DemoServer** file watch monitors **both** paths (when they differ).

**Authoring** (shape rules, `rowId` joins — not runtime behavior): [skills/kawarimi-user-mock-and-scenario-format/SKILL.md](../skills/kawarimi-user-mock-and-scenario-format/SKILL.md). **`KawarimiValidate`** before commit — same skill.

#### HTTP headers (`KawarimiScenarioHeaders`)

| Header | Direction | Role |
| --- | --- | --- |
| `X-Kawarimi-Scenario-Id` | Request | Select scenario |
| `X-Kawarimi-Id` | Request | Current step; omit on first request |
| `X-Next-Kawarimi-Id` | Response | Next step for the client; omitted when `next` is unset |

#### Server (`KawarimiServerMiddleware`)

When **`X-Kawarimi-Scenario-Id`** is present, **`KawarimiScenarioResolver`** runs **before** `X-Kawarimi-Example-Id` / standard override matching.

- **Matched** — return the override for `rowId` and attach **`X-Next-Kawarimi-Id`** when the case defines `next`.
- **Not matched** (unknown scenario, duplicate `scenarioId`+`endpoint`+`kawarimiId`, missing override, endpoint mismatch, invalid headers) — **fall back** to existing override resolution (no `503`).

#### Client (`KawarimiClientOrchestrationMiddleware`)

OpenAPI **`ClientMiddleware`** in **KawarimiClient** (depends on swift-openapi-runtime):

- **`scenarioIdProvider`** — your app supplies the active scenario id per request (optional).
- Request header **`X-Kawarimi-Scenario-Id`** wins over the provider when both are set.
- When a scenario id is active, inject **`X-Kawarimi-Id`** from per-scenario state (updated from **`X-Next-Kawarimi-Id`** on responses).
- Terminal response (no **`X-Next-Kawarimi-Id`**) clears state for that scenario — including error responses without a next header (the next request restarts from `initial` on the server).
- **Concurrent requests** for the same `scenarioId` share one state map; the last response’s **`X-Next-Kawarimi-Id`** wins (documented behavior for parallel UI/tests).
- **`reset(scenarioId:)`** / **`resetAll()`** for tests or manual reset.

Invalid scenario JSON on disk logs **warnings** at load/reload; requests still fall back. **`KawarimiValidate`** exists to fail CI instead of relying on this soft behavior — [validation.md](../skills/kawarimi-user-mock-and-scenario-format/validation.md).

Sample committed fixtures and curl notes: [Example/README.md](../Example/README.md).

| Endpoint | Description |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | Upsert an override. Returns **`200`** with a JSON override array (same shape as **`GET …/status`**). |
| `POST {pathPrefix}/__kawarimi/remove` | Remove one override row (same identity as `configure`). Returns **`200`** with a JSON override array. Idempotent. |
| `GET {pathPrefix}/__kawarimi/status` | List active overrides |
| `POST {pathPrefix}/__kawarimi/reset` | Clear all overrides. Returns **`200`** with a JSON override array (typically `[]`). |
| `POST {pathPrefix}/__kawarimi/reload` | Re-read **`kawarimi.json`** into `KawarimiConfigStore` (same as file-watch reload). Returns **`200`** with **`X-Kawarimi-Reload: applied`** (cache updated) or **`unchanged`** (decoded overrides already matched memory), and a JSON override array (same shape as **`GET …/status`**). Not for spec / `responseMap` refresh. |
| `GET {pathPrefix}/__kawarimi/spec` | Return the full KawarimiSpec (meta + endpoints) |

### Admin error responses

Reference HTTP contract: [`KawarimiAdminHTTPHandler`](../Sources/KawarimiServer/KawarimiAdminHTTPHandler.swift). Vapor wiring: [`KawarimiAdminVaporMiddleware.swift`](../Example/DemoPackage/Sources/DemoServer/KawarimiAdminVaporMiddleware.swift). Hosts may differ; clients treat non-2xx as **`KawarimiAPIError`**.

| Route | Status | Response body |
|---|---|---|
| `POST …/configure` | `400` | Plain text (`Invalid JSON body: …`) when the body is not valid **`MockOverride`** JSON |
| `POST …/configure` | `413` | Plain text when override **`body`** exceeds **`MockOverride.maxBodyLength`** (65536 bytes) |
| `POST …/configure` | `500` | Plain text for **`KawarimiConfigStoreError`** or persistence failures |
| `POST …/remove` | `400` | Plain text when the body is not valid **`MockOverride`** JSON |
| `POST …/remove` | `500` | Plain text for store failures |

Successful JSON responses (**`GET …/status`**, **`GET …/spec`**, **`POST …/configure`**, **`POST …/remove`**, **`POST …/reset`**, **`POST …/reload`**) use **`Content-Type: application/json`** (**`KawarimiAdminHeaders.jsonContentType`**). **`POST …/reload`** also sets **`X-Kawarimi-Reload`**.

**`KawarimiAPIClient`**: **`configure`**, **`removeOverride`**, and **`reset`** decode the post-mutation override list from the response body. **`configureAndFetchOverrides`** and similar names remain as aliases (no extra **`GET …/status`**).

**KawarimiHenge (`KawarimiConfigView`):** pass a **`KawarimiAPIClient`** whose **`baseURL`** matches your admin mount (e.g. `http://127.0.0.1:8080/api`). Spec and endpoints are fetched via **`GET …/__kawarimi/spec`** (`HengeSpecSnapshot`).

The UI shows **`meta.serverURL`** from that fetch once loaded (falls back to **`client.baseURL`** until the first spec load).

The minus (**Del**) control **removes the saved row** for the current response chip when one exists in `kawarimi.json` (**`POST …/__kawarimi/remove`**, using the row’s persisted **`path`** / **`exampleId`**). When there is **no saved row** but the editor has an **unsaved draft**, **Del** clears the draft locally toward Spec **without** calling the server. To turn a mock off but **keep** the row (disabled preset with JSON), use an **inactive chip + Save** — not **Del**.

**Numbered chips from OpenAPI** (e.g. **200 formal**, **200 success**) are **always shown** from the spec document. **Del** removes **saved** rows in `kawarimi.json` only — it does not hide OpenAPI chips. Rows saved without `exampleId` whose body matches a named example’s template are still matched for **Del** (legacy configs).

Sample **`curl`** for this repository’s **DemoServer**: [Example/README.md#try-the-henge-api-demoserver](../Example/README.md#try-the-henge-api-demoserver).

## Override editor (`OverrideEditorView`)

The SwiftUI mock UI is **`OverrideEditorView`** in **KawarimiHenge** (endpoint explorer + detail column).

<a id="henge-explorer-state"></a>

### Explorer state model (three cooperating pieces)

1. **Server snapshot (read-mostly)** — **`KawarimiConfigView`** owns `@State` for **`meta`**, **`endpoints`**, and **`overridesSnapshot`** (the decoded **`GET …/__kawarimi/status`** list). It passes them into **`OverrideEditorView`** as plain `let` inputs. The explorer list, example captions, **`primaryOverride(for:)`**, and chip rows backed by **stored** overrides all read this snapshot so they reflect the last successful status fetch.

2. **Editor draft (per selection)** — **`OverrideEditorStore`** (`@Observable`) holds an optional **`OverrideDetailDraft`** for the **open** row: **`mock`**, **`isDirty`**, **`pinnedNumberedResponseChip`**, **`validationMessage`**. It is **not** a copy of the whole overrides array. **Stashed drafts** — when you switch endpoints with **`isDirty`**, the previous row’s draft is copied into **`pendingDraftsByRowKey`**; selecting that row again restores it (spec reload clears stashes).

3. **Mutation bridge** — The child receives **`configureOverride`** / **`removeOverride`** typed as **`(MockOverride) async throws -> [MockOverride]`**. The parent’s wrapper (on **`KawarimiConfigView`**) may call **`disableConflictingStatusMocks`**, then the bare **`KawarimiAPIClient`** **`configure`** / **`remove`**, and assigns **`overridesSnapshot`** from the **response body** (no follow-up **`GET …/status`**). **`OverrideEditorStore`** uses that returned array in **`resyncDetailAfterOverridesRefresh`** immediately after a successful **Save** / **Reset** / **Del → remove** path (**`markSavedClean()`** first), so the draft matches the server response without relying on SwiftUI scheduling.

<a id="henge-dirty-vs-unsaved"></a>

#### `isDirty` vs “Not saved” / sidebar dot

| Signal | Meaning | Code |
| --- | --- | --- |
| **`isDirty`** | The user performed an editing action that should **block** automatic **`resyncDetailAfterOverridesRefresh`** and **stash** the draft when leaving the row. | Set on body/mock edits, **Format**, **`applyMockEdit`**, etc.; cleared on successful save path, spec reload resync, reset payloads. |
| **“Not saved” / dot** | The draft’s **persistable** mock fields differ from the **current** `overridesSnapshot` canonical (what **`resyncMockFromServer`** would produce), tolerant of JSON whitespace. **Independent** of `isDirty` — e.g. formatted JSON can match the server while `isDirty` is still true. | **`OverrideDetailDraft.persistableMockDiffersFromServer`**, equality via **`OverrideListQueries.persistableMockConfigurationEqual`**. |

<a id="henge-draft-bootstrap"></a>

#### Draft bootstrap (open from list)

With **no** stashed draft, **`OverrideExplorerDraftBootstrap.makeFreshDetail`** builds **`MockDraftDefaults.specPlaceholder`**, optionally overlays the server **primary** (`statusCode`, `exampleId`, `isEnabled`, `name`) when **`OverrideListQueries.primaryEnabledOverride`** exists, then **`resyncMockFromServer`**. That prevents **`storedOverride`** from binding the placeholder **(200, nil)** to the wrong JSON row when a **disabled** default line appears **before** the **enabled** primary (which would disagree list **P** vs **Spec** chip).

<a id="henge-ui-data-flow"></a>

#### Lifecycle / list refresh

4. **Spec + overrides reload** — **`loadSpecAndOverrides()`** bumps **`specLoadID`**; **`OverrideEditorView`**’s **`.task(id: specLoadID)`** calls **`resyncDetailAfterSpecReload`** (drops stashed drafts, replaces open detail from the new spec + status).

5. **Explorer list identity** — **`overridesRevision`** increments after each overrides-only fetch; **`OverrideEditorView`** applies it as **`.id(…)`** on **`List`**s so split-view rows refresh reliably.

<a id="henge-editor-ux"></a>

### User workflow (UX)

Pick an endpoint, then a **response row** (chips), edit JSON if needed, and tap **Save** (`configure`, or **`remove`** when following Spec — see below).

| Goal | What to do |
| --- | --- |
| Rely on OpenAPI only for this operation (effective **Spec**) | Tap **Spec** (draft clears to the operation’s **first** spec status, no named example, empty editor body). When the draft is **Spec-shaped** and you are on the **Spec** chip, **Save** **`remove`s** a matching stored default row if one exists (no ghost row in `kawarimi.json`); otherwise no HTTP. When **no** row is enabled on the server, **Spec** is the effective response; the **Spec** chip is visually emphasized. |
| Return the UI to that “template-only” state without deleting rows yet | Tap **Spec** (clears body) or rely on **no enabled mock** + default disabled row: **Spec** highlights even when the editor shows merged OpenAPI JSON; tap **200 OK** if you want the numbered chip while editing the same template. |
| Mock one documented response (make it **primary** on the server) | Select the **status / example** chip (draft **`isEnabled: true`**), edit body, **Save**. **`KawarimiConfigView`** turns **`isEnabled: false`** on every **other** enabled row for the **same OpenAPI operation** first (any status / `exampleId`), then saves the current row **enabled** — only one active mock per operation in normal use. |
| Add a status (or example) not in the doc | **+** (Add response), pick status, edit on the main screen, **Save** (enabled or off depending on chip / stored row). |
| Persist JSON but **do not** make it the active mock | Choose a chip whose row is **off** (e.g. copy from a stored disabled row), edit body, **Save** — sends **`isEnabled: false`** with **body** / **contentType** preserved. |
| Turn the mock off but keep the row in `kawarimi.json` | Select an **inactive** chip row and **Save** ( **`isEnabled: false`** with body preserved). |
| Remove the saved row for the **current** chip | **Del** when a matching saved row exists (calls **`remove`** in one step, whether the row is enabled or disabled). |
| Remove all **disabled** rows for this operation | Tap the **trash** action in the detail header (removes every disabled row for the selected operation; enabled rows stay untouched). |
| Clear an **unsaved** draft only | **Del** when no saved row exists for the chip but the editor differs from the server snapshot (no HTTP). |
| Reset the **default** row to “off + cleared” and align the editor | **Reset** in the bottom bar — same Spec-only path as **Save** on **Spec**: **`remove`** when a matching default stored row exists, else **`configure`**. **Other** chips’ rows for the same operation stay in `kawarimi.json` until you **Del** each. |
| Clear every override | **Reset all overrides** in the explorer chrome (with confirmation). |
| Re-read `kawarimi.json` on the server after disk edits | **Reload kawarimi.json** in the explorer chrome — **`POST …/__kawarimi/reload`** (overrides in the response body). Shows **applied** or **unchanged** under the button. Does not refetch spec. |

**Save** builds **`SavePayload.build(mock:endpoint:pinnedNumberedResponseChip:)`**. If the draft is **Spec-shaped** (see below) **and** the user is on the **Spec** chip (`pinnedNumberedResponseChip` is false), **`OverrideEditorStore`** **`remove`s** a matching stored default row when one exists (**`SavePayload.isSpecOnlyRemovePayload`**); otherwise no HTTP — it does **not** upsert a disabled placeholder. If the user chose a **numbered** chip (pin true) but the stored row is still **off** (draft can match the template), **Save** **`configure`s** with **enabled** so **200 OK** (etc.) becomes primary. Otherwise **`mock.isEnabled`** chooses **enabled** vs **disabled** via **`configure`**; **disabled** saves still include trimmed **body** / **contentType** on the wire.

**Primary badge (`P`)** on a **detail** numbered chip matches the **server’s** primary enabled row only (not unsaved edits). The **endpoint list** shows the primary’s HTTP status (and example caption) **without** a **P** badge. If **two or more** enabled rows exist for the same operation (e.g. hand-edited config), the list shows a **warning**; the server and explorer both use the first row after `sortedForOverrideTieBreak` (same Core ordering).

**Del** (−): matching **saved** row → **`remove`** (row deleted from config, editor reset toward Spec). **`OverrideListQueries.storedOverrideForDel`** matches exact identity first, then legacy rows without `exampleId` whose body matches the chip’s OpenAPI template. **Unsaved draft only** → local clear (no server call). **Off but keep JSON** → inactive chip + **Save**, not **Del**. OpenAPI numbered chips remain visible after **Del** — only **`kawarimi.json`** rows are removed.

**Refresh / sync:** The editor assumes a **local, single-user** workflow — there is **no confirmation dialog** when a refresh would replace the open detail. **Reloading spec** (toolbar **Refresh**) refetches endpoints and **replaces the current detail** from server state (unsaved edits are dropped). **Reload kawarimi.json** re-reads overrides from disk on the server only; it updates the explorer list and resyncs the open detail when **`isDirty`** is false, and shows whether the server applied new file contents (**applied**) or already matched memory (**unchanged**). After **Save** / **configure** / **remove**, the parent returns the **fresh** status array to the store, which **always** resyncs the open detail when the save path succeeds (**`markSavedClean()`** then **`resyncDetailAfterOverridesRefresh`**; the resync guard **`!isDirty`** is satisfied on that path). **Switching to another endpoint stashes a dirty draft per row** so returning restores it (spec reload clears stashed drafts).

---

### Implementors (code map)

**Editing rules** live in **`KawarimiHengeCore`** (`Sources/KawarimiHengeCore/`) — `ResponseChips`, `SavePayload`, `DisableMockPlanner`, `EndpointFilter`, **`OverrideListQueries`**, **`OverrideExplorerDraftBootstrap`**. **Selection + draft meta** (`validationMessage`, `isDirty`) are **`OverrideEditorStore`** / **`OverrideDetailDraft`**. SwiftUI is **`KawarimiHenge`** (`Sources/KawarimiHenge/`).

| UI / doc term | Code | Notes |
| --- | --- | --- |
| Endpoint list row | `EndpointRowKey` + `SpecEndpointItem` | Selection is by `EndpointRowKey`. |
| First draft when opening a row (no stash) | `OverrideExplorerDraftBootstrap.makeFreshDetail` | Placeholder → primary overlay → `resyncMockFromServer`. |
| Detail editor | One `MockOverride` in `OverrideDetailDraft` | Snapshot for the selected logical row, not the whole overrides array. |
| Server / config row | `MockOverride` in `kawarimi.json` | Identity is **`rowId` first** (UUID). Legacy fallback: **`path` + `method` + `statusCode` + normalized `exampleId`** only when incoming `rowId` is nil. |
| Persisted row ID (detail header) | `RowIdPresentation.displayRowId` | Shown when the selected chip matches a stored row with **`rowId`**; **Copy** places the UUID on the pasteboard (for `kawarimi-scenarios.json`). Spec-only or unsaved drafts omit the block. |
| Default / unnamed example | `exampleId` nil (after trim) | Lookup uses reserved **`__default`**; UI “no example id”. |

**Response chips:** OpenAPI **numbered** rows (status + named example) are always listed from the spec. **Supplemental** chips appear only for **stored** overrides that are not already represented (e.g. custom status codes). Disabled no-body “spec-follow” ghost rows are hidden from supplemental chips (**`OverrideListQueries.isSpecFollowGhostRow`**). **`ResponseChips.chipIsSelected`** (mock off) treats **`draftRepresentsSpecOnlyRowForSave`** like **Save** (empty or template-matching body) for highlighting **Spec**, unless **`OverrideDetailDraft.pinnedNumberedResponseChip`** is set (cleared on resync, successful **Save**, reset, and whenever the store changes the draft body or mock fields — `applyMockEdit`, **Format**).

**SavePayload** early exit uses **`draftRepresentsSpecOnlyRowForSave`** only.

**Exclusive active mock:** **`KawarimiConfigView`**’s `configure` wrapper calls **`OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow`** so that, before the enabled row is written, every **other** enabled override for the same operation (same `operationId` or aligned path; **any** status/`exampleId` pair except the row being saved) is **`configure`**d with **`isEnabled: false`** only — **`body` / `contentType` on those peers are unchanged**.

**Save** — UI uses **`SavePayload.build`**, then **`OverrideEditorStore`**: if **`SavePayload.isSpecOnlyRemovePayload`** and a matching stored default row exists → **`remove`**; if Spec-only shape but no stored row → no HTTP. Otherwise **`configure`**. **`buildApplyPrimary`** / **`buildSaveInactive`** still build the Spec-only **shape** for tests; the store decides remove vs configure.

**Del** — **`DisableMockPlanner`** via **`storedOverrideForDel`**: saved row for the chip → **`remove`** with **`removeIdentity`** (persisted path / exampleId) + draft reset toward spec; unsaved draft only → **local clear**; else **no-op**.

**Automated tests:** Henge explorer logic in **`KawarimiHengeCoreTests`** (`Tests/KawarimiHengeCoreTests/`, module **`KawarimiHengeCore`**). Ubuntu CI runs **`KawarimiHengeCore`** only; full **`KawarimiHenge`** (SwiftUI) on macOS locally.

## Client: real server vs Kawarimi mock

Use **two** generated `Client` instances if you want both in-process mocks and a live server:

- `Kawarimi()` — no network; responses use the rules in [mock-json.md](mock-json.md) (per-operation 200 + `application/json`).
- `URLSessionTransport()` from [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) against your HTTP server (add that product to your target).

`KawarimiSpec` (and Henge / `responseMap`) is **not** filled by the same generator pass as the in-process `Kawarimi` transport.

See **`KawarimiSpec` vs in-process `Kawarimi` transport** in [mock-json.md](mock-json.md).

This repository includes **DemoServer** and **DemoApp** under **`Example/`** — see [Example/README.md](../Example/README.md).

If you need **one** client that switches real vs mock at runtime, implement a small `ClientTransport` wrapper in your app that forwards to `URLSessionTransport` and picks `baseURL` / headers.

<a id="kawarimijson--kawarimi_config"></a>

## `kawarimi.json` / `KAWARIMI_CONFIG`

`KawarimiConfigStore` (**KawarimiCore**) reads and writes overrides to a JSON file (default: `kawarimi.json` in the working directory).

The file format uses `KawarimiConfig` (overrides array). **Authoring** rules (why fields exist, not runtime): [skills/kawarimi-user-mock-and-scenario-format/SKILL.md](../skills/kawarimi-user-mock-and-scenario-format/SKILL.md).

Set `KAWARIMI_CONFIG` to override the config file path.

`KAWARIMI_CONFIG_WATCH` controls automatic reload when the config file changes on disk: **unset** or **`1`** → watch enabled; **`0`** → disabled. Values such as **`false`** are treated as enabled (only **`0`** turns watch off). **DemoServer** calls `startFileWatchIfEnabled()` at startup; other hosts should do the same if they want the same behavior.

### `kawarimi-scenarios.json` / `KAWARIMI_SCENARIOS_CONFIG`

Scenario definitions are loaded by the same store (read-only; not written by `configure`). Path resolution order:

1. `scenariosPath:` argument to **`KawarimiConfigStore`** init (when non-empty)
2. **`KAWARIMI_SCENARIOS_CONFIG`** environment variable
3. **`kawarimi-scenarios.json`** next to the resolved `kawarimi.json` path

`kawarimi.json` holds runtime `overrides` only; use `kawarimi-generator-config.yaml` for `handlerStubPolicy` and codegen toggles (`generateKawarimi`, `generateHandler`, `generateSpec`).

Each override may include optional **`delayMs`** (integer milliseconds, 1–60000). Omitted, `null`, `0`, or negative values mean no delay. The reference interceptor sleeps before returning the mock response.

Starter **`kawarimi.json`**, sample **`kawarimi-generator-config.yaml`**, and **`swift run DemoServer` working-directory notes** for this repository: [Example/README.md](../Example/README.md).

Empty-string `body` / `contentType` on an override is normalized to “not set” when saved; at response time, an empty body falls back to the spec response.

If several overrides match the same request (same path template + method), **`KawarimiServerMiddleware`** **sorts** by `MockOverride.sortedForOverrideTieBreak` and uses the **first** entry.

Comparison order:

`path`, then `statusCode`, then `name`, then `exampleId`.

Equal keys keep **`hits` order** (Swift stable `sort`). A warning is still logged with that order.

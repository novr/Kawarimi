# Dynamic mock (KawarimiHenge)

**Build time:** the **Kawarimi** plugin generates `KawarimiSpec.swift` with endpoints and response bodies as Swift constants.

**Runtime** mock switching — overrides without recompiling — is a **KawarimiHenge** feature.

Add **KawarimiCore** for `KawarimiAPIClient` (HTTP to `{pathPrefix}/__kawarimi/*`) and **KawarimiHenge** for SwiftUI (`KawarimiConfigView`).

On the server, use **KawarimiCore** (`KawarimiConfigStore`, `PathTemplate`, `MockOverride`, …) and register the **Henge API** routes.

**Vapor `AsyncMiddleware` that applies overrides is not a KawarimiCore product** — copy or adapt the reference [`KawarimiInterceptorMiddleware.swift`](../Example/DemoPackage/Sources/DemoServer/KawarimiInterceptorMiddleware.swift) (see [Example README](../Example/README.md)).

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

<a id="hengecli-macos"></a>

## HengeCli (macOS sample app)

**`Example/DemoPackage`** defines an executable product **`HengeCli`**.

It is a **macOS-only** SwiftUI app that embeds **`KawarimiConfigView`** with a **`KawarimiAPIClient`**. The client’s **`baseURL`** comes from generated **`KawarimiSpec.meta`** (`serverURL` + `apiPathPrefix`), same idea as the Demo app’s config — see `Sources/HengeCli/HengeCliConfig.swift`.

- **Run:** from `Example/DemoPackage`, `swift run HengeCli` (or `swift build --product HengeCli`).  
  Start **`DemoServer`** (or any server that serves Henge under the URL your OpenAPI `servers` entry describes) first.

- **Window lifecycle:** closing the **last window quits** the process (`applicationShouldTerminateAfterLastWindowClosed`).

  On launch, **`NSApp.activate(ignoringOtherApps: true)`** and **`makeKeyAndOrderFront`** run so the window is key when launched from Terminal or other non-GUI parents (text fields and editors accept input reliably).

- **Bad base URL:** if `servers` / prefix cannot be resolved to a URL, the UI shows **`ContentUnavailableView`** with a hint to fix `openapi.yaml` and regenerate.

iOS and other platforms compile a **stub** `main` that exits with an error message.

Use **`DemoApp`** or your own target for those platforms.

## Generated file: `KawarimiSpec.swift`

`KawarimiSpec` is generated into your API target and exposes:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // all endpoints with their possible responses
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: [exampleId: (body, contentType)]]
```

The generated **`SpecResponse`** type conforms to **`KawarimiFetchedSpec`**.

So **`KawarimiConfigView(client:specType:)`** can decode `/__kawarimi/spec` without manual wiring.

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

`KawarimiConfigStore.configure` treats overrides as distinct when **`path`, HTTP method, `statusCode`, and normalized `exampleId`** match.

`configure` **upserts** one row: set `isEnabled: false` to turn a mock off while **keeping** that row in `kawarimi.json`.

**`KawarimiConfigStore.removeOverride`** deletes the first row with the **same identity** (after the same normalization as `configure`). Calling `removeOverride` when nothing matches is a **no-op** (idempotent).

Two enabled overrides for the same path/method but different examples are distinguished by `exampleId`.

For how mock JSON strings are chosen, see [mock-json.md](mock-json.md).

## Henge API (`{pathPrefix}/__kawarimi/*`)

**Henge API** is the HTTP surface that **`KawarimiAPIClient`** (in **KawarimiCore**) talks to (the name “Henge” is the feature).

Mount admin routes **under a path prefix aligned with your OpenAPI API** (e.g. **`/api/__kawarimi/spec`** when the API lives under `/api`).

You may mount `__kawarimi` at the root in your own app; keep it aligned with `KawarimiAPIClient`’s `baseURL`.

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

For **per-request** disambiguation (not `configure` JSON), the Example middleware reads **`X-Kawarimi-Example-Id`**.

The header name in code is **`KawarimiMockRequestHeaders.exampleId`** in **KawarimiCore**.

When **several enabled overrides** match the same path and method, a non-empty header **narrows** candidates to overrides whose effective example map key matches (same rules as ``KawarimiExampleIds/responseMapLookupKey(forOverrideExampleId:)`` — e.g. `success` matches an override with `exampleId` `"success"`; use `__default` to target the default example row).

If narrowing would match **no** overrides, the middleware **ignores** the header and uses all candidates (then tie-break as usual).

Omit the header or send whitespace-only to apply **no** narrowing.

| Endpoint | Description |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | Upsert an override for a path/method/statusCode (and optional `exampleId`). Set `isEnabled` / `body` / `contentType` as needed. |
| `POST {pathPrefix}/__kawarimi/remove` | Remove one override row that matches the same identity as `configure` (normalized path, method, `statusCode`, `exampleId`). Idempotent. |
| `GET {pathPrefix}/__kawarimi/status` | List active overrides |
| `POST {pathPrefix}/__kawarimi/reset` | Clear all overrides |
| `GET {pathPrefix}/__kawarimi/spec` | Return the full KawarimiSpec (meta + endpoints) |

**KawarimiHenge (`KawarimiConfigView`):** pass a **`KawarimiAPIClient`** (aligned with your API `baseURL`) and your generated **`SpecResponse.self`** (conforms to **`KawarimiFetchedSpec`**).

The UI shows **`client.baseURL.absoluteString`** as the server label.

The minus (**Del**) control persists **`isEnabled: false`** for the current response chip when the mock is on.

When the mock is **already off** and a **saved** row exists for that chip, **Del** calls **`remove`** so the row is dropped from the server config and the editor returns to the spec draft (same HTTP as **`KawarimiAPIClient.removeOverride(override:)`** in **KawarimiCore**).

Sample **`curl`** for this repository’s **DemoServer**: [Example/README.md#try-the-henge-api-demoserver](../Example/README.md#try-the-henge-api-demoserver).

## Override editor (`OverrideEditorView`)

The SwiftUI mock UI is **`OverrideEditorView`** in **KawarimiHenge** (endpoint explorer + detail column).

<a id="henge-explorer-state"></a>

### Explorer state model (three cooperating pieces)

1. **Server snapshot (read-mostly)** — **`KawarimiConfigView`** owns `@State` for **`meta`**, **`endpoints`**, and **`overridesSnapshot`** (the decoded **`GET …/__kawarimi/status`** list). It passes them into **`OverrideEditorView`** as plain `let` inputs. The explorer list, example captions, **`primaryOverride(for:)`**, and chip rows backed by **stored** overrides all read this snapshot so they reflect the last successful status fetch.

2. **Editor draft (per selection)** — **`OverrideEditorStore`** (`@Observable`) holds an optional **`OverrideDetailDraft`** for the **open** row: **`mock`**, **`isDirty`**, **`pinnedNumberedResponseChip`**, **`validationMessage`**. It is **not** a copy of the whole overrides array. **Stashed drafts** — when you switch endpoints with **`isDirty`**, the previous row’s draft is copied into **`pendingDraftsByRowKey`**; selecting that row again restores it (spec reload clears stashes).

3. **Mutation bridge** — The child receives **`configureOverride`** / **`removeOverride`** typed as **`(MockOverride) async throws -> [MockOverride]`**. The parent’s wrapper (on **`KawarimiConfigView`**) may call **`disableConflictingStatusMocks`**, then the bare **`KawarimiAPIClient`** **`configure`** / **`remove`**, then **`refreshOverridesOnly()`**, which assigns **`overridesSnapshot`** and **`return`s the same `[MockOverride]`** produced by the fetch (so the return value never re-reads **`@State`** for that array). **`OverrideEditorStore`** uses that returned array in **`resyncDetailAfterOverridesRefresh`** immediately after a successful **Save** / **Reset** / **Del-disable** path (**`markSavedClean()`** first), so the draft matches the server response without relying on SwiftUI scheduling.

<a id="henge-dirty-vs-unsaved"></a>

#### `isDirty` vs “Not saved” / sidebar dot

| Signal | Meaning | Code |
| --- | --- | --- |
| **`isDirty`** | The user performed an editing action that should **block** automatic **`resyncDetailAfterOverridesRefresh`** and **stash** the draft when leaving the row. | Set on body/mock edits, **Format**, **`applyMockEdit`**, etc.; cleared on successful save path, spec reload resync, reset payloads. |
| **“Not saved” / dot** | The draft’s **persistable** mock fields differ from the **current** `overridesSnapshot` canonical (what **`resyncMockFromServer`** would produce), tolerant of JSON whitespace. **Independent** of `isDirty` — e.g. formatted JSON can match the server while `isDirty` is still true. | **`OverrideDetailDraft.persistableMockDiffersFromServer`**, equality via **`OverrideListQueries.persistableMockConfigurationEqual`**. |

<a id="henge-draft-bootstrap"></a>

#### Draft bootstrap (open from list)

When there is **no** stashed draft, **`OverrideExplorerDraftBootstrap.makeFreshDetail`** builds the first draft: **`MockDraftDefaults.specPlaceholder`**, then—if **`OverrideListQueries.primaryEnabledOverride`** exists—overlays **`statusCode`**, **`exampleId`**, **`isEnabled`**, **`name`** from that primary, then runs **`resyncMockFromServer`**. That avoids **`storedOverride`** matching the **first** JSON row with the placeholder’s default **(200, nil)** when your config lists a **disabled** default row **before** the **enabled** custom row (e.g. 503): without the overlay, the **Spec** chip could highlight while **P** still marks the real primary.

<a id="henge-ui-data-flow"></a>

#### Lifecycle / list refresh

4. **Spec + overrides reload** — **`loadSpecAndOverrides()`** bumps **`specLoadID`**; **`OverrideEditorView`**’s **`.task(id: specLoadID)`** calls **`resyncDetailAfterSpecReload`** (drops stashed drafts, replaces open detail from the new spec + status).

5. **Explorer list identity** — **`overridesRevision`** increments after each overrides-only fetch; **`OverrideEditorView`** applies it as **`.id(…)`** on **`List`**s so split-view rows refresh reliably.

<a id="henge-editor-ux"></a>

### User workflow (UX)

Pick an endpoint, then a **response row** (chips), edit JSON if needed, and tap **Save** to call `configure` on the server.

| Goal | What to do |
| --- | --- |
| Rely on OpenAPI only for this operation (effective **Spec**) | Tap **Spec** (draft clears to the operation’s **first** spec status, no named example, empty editor body). **Save** sends the Spec-only **disable** payload when the draft is **Spec-shaped**. When **no** row is enabled on the server, **Spec** is the effective response; the **Spec** chip is visually emphasized. |
| Return the UI to that “template-only” state without deleting rows yet | Tap **Spec** (clears body) or rely on **no enabled mock** + default disabled row: **Spec** highlights even when the editor shows merged OpenAPI JSON; tap **200 OK** if you want the numbered chip while editing the same template. |
| Mock one documented response (make it **primary** on the server) | Select the **status / example** chip (draft **`isEnabled: true`**), edit body, **Save**. **`KawarimiConfigView`** turns **`isEnabled: false`** on every **other** enabled row for the **same OpenAPI operation** first (any status / `exampleId`), then saves the current row **enabled** — only one active mock per operation in normal use. |
| Add a status (or example) not in the doc | **+** (Add response), pick status, edit on the main screen, **Save** (enabled or off depending on chip / stored row). |
| Persist JSON but **do not** make it the active mock | Choose a chip whose row is **off** (e.g. copy from a stored disabled row, or **Del** after turning off), edit body, **Save** — sends **`isEnabled: false`** with **body** / **contentType** preserved. |
| Turn the mock off but keep the row in `kawarimi.json` | **Del** while the mock is on, or select an **inactive** chip row and **Save**. |
| Remove the saved row for the **current** chip | **Del** when the mock is already off and a matching saved row exists (calls **`remove`**). |
| Reset the **default** row to “off + cleared” and align the editor | **Reset** in the bottom bar — sends **`configure`** for the operation’s **first** spec status (no named example) only. **Other** chips’ rows for the same operation stay in `kawarimi.json` until you **Del** each. |
| Clear every override | **Reset all overrides** in the explorer chrome (with confirmation). |

**Save** builds **`SavePayload.build(mock:endpoint:pinnedNumberedResponseChip:)`** then `configure`. If the draft is **Spec-shaped** (see below) **and** the user is on the **Spec** chip (`pinnedNumberedResponseChip` is false), **Save** sends **`isEnabled: false`** and cleared body fields for that default row — even if an **enabled** line for the same keys was still on the server — so you don’t accidentally stay “active” after choosing **Spec**. If the user chose a **numbered** chip (pin true) but the stored row is still **off** (draft can match the template), **Save** sends **enabled** so **200 OK** (etc.) becomes primary. Otherwise **`mock.isEnabled`** chooses **enabled** vs **disabled**; **disabled** saves still include trimmed **body** / **contentType** on the wire.

**Primary badge (`P`)** on a **detail** numbered chip matches the **server’s** primary enabled row only (not unsaved edits). The **endpoint list** shows the primary’s HTTP status (and example caption) **without** a **P** badge. If **two or more** enabled rows exist for the same operation (e.g. hand-edited config), the list shows a **warning**; the interceptor uses the first row after server ordering (`sortedForInterceptorTieBreak`).

**Del** (−): mock **on** → **`configure`** with **off** for the same keys; mock **off** and a **saved** row matches the chip → **`remove`** (row deleted from config).

**Refresh / sync:** The editor assumes a **local, single-user** workflow — there is **no confirmation dialog** when a refresh would replace the open detail. **Reloading spec** refetches endpoints and **replaces the current detail** from server state (unsaved edits are dropped). After **Save** / **configure** / **remove**, the parent returns the **fresh** status array to the store, which **always** resyncs the open detail when the save path succeeds (**`markSavedClean()`** then **`resyncDetailAfterOverridesRefresh`**; the resync guard **`!isDirty`** is satisfied on that path). **Switching to another endpoint stashes a dirty draft per row** so returning restores it (spec reload clears stashed drafts).

---

### Implementors (code map)

**Editing rules** live under **`Sources/KawarimiHenge/EditorSupport/`** — `ResponseChips`, `SavePayload`, `DisableMockPlanner`, `EndpointFilter`, **`OverrideListQueries`**, **`OverrideExplorerDraftBootstrap`**. **Selection + draft meta** (`validationMessage`, `isDirty`) are **`OverrideEditorStore`** / **`OverrideDetailDraft`**.

| UI / doc term | Code | Notes |
| --- | --- | --- |
| Endpoint list row | `EndpointRowKey` + `SpecEndpointItem` | Selection is by `EndpointRowKey`. |
| First draft when opening a row (no stash) | `OverrideExplorerDraftBootstrap.makeFreshDetail` | Placeholder → primary overlay → `resyncMockFromServer`. |
| Detail editor | One `MockOverride` in `OverrideDetailDraft` | Snapshot for the selected logical row, not the whole overrides array. |
| Server / config row | `MockOverride` in `kawarimi.json` | Same identity as configure/remove: **`path` + `method` + `statusCode` + normalized `exampleId`**. |
| Default / unnamed example | `exampleId` nil (after trim) | Lookup uses reserved **`__default`**; UI “no example id”. |

**Response chips (mock off):** **`ResponseChips.chipIsSelected`** treats **`draftRepresentsSpecOnlyRowForSave`** like **Save** (empty or template-matching body) for highlighting **Spec**, unless **`OverrideDetailDraft.pinnedNumberedResponseChip`** is set (cleared on resync, successful **Save**, reset, and whenever the store changes the draft body or mock fields — `applyMockEdit`, **Format**).

**SavePayload** early exit uses **`draftRepresentsSpecOnlyRowForSave`** only.

**Exclusive active mock:** **`KawarimiConfigView`**’s `configure` wrapper calls **`OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow`** so that, before the enabled row is written, every **other** enabled override for the same operation (same `operationId` or aligned path; **any** status/`exampleId` pair except the row being saved) is **`configure`**d with **`isEnabled: false`** only — **`body` / `contentType` on those peers are unchanged**.

**Save** — UI uses **`SavePayload.build(mock:endpoint:pinnedNumberedResponseChip:)`**. If **`draftRepresentsSpecOnlyRowForSave`** and **not** **`pinnedNumberedResponseChip`**, return the fixed **disabled** payload for the first spec status (early exit). Otherwise branch on **`mock.isEnabled`** or **pin** (numbered chip → treat as **enabled** when turning a template-matching inactive row on). **`buildApplyPrimary`** / **`buildSaveInactive`** remain for tests or forced paths.

**Del** — **`DisableMockPlanner`**: active mock → `configure` **off**; off + matching stored row → **`remove`** + draft reset toward spec; else **no-op**.

**Automated tests:** **`KawarimiHengeTests`** (`Tests/KawarimiHengeTests/`).

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

The file format uses `KawarimiConfig` (overrides array).

Set `KAWARIMI_CONFIG` to override the config file path.

`kawarimi.json` holds runtime `overrides` only; use `kawarimi-generator-config.yaml` for `handlerStubPolicy`.

Starter **`kawarimi.json`**, sample **`kawarimi-generator-config.yaml`**, and **`swift run DemoServer` working-directory notes** for this repository: [Example/README.md](../Example/README.md).

Empty-string `body` / `contentType` on an override is normalized to “not set” when saved; at response time, an empty body falls back to the spec response.

If several overrides match the same request (same path template + method), the interceptor **sorts** by `MockOverride.sortedForInterceptorTieBreak` and uses the **first** entry.

Comparison order:

`path`, then `statusCode`, then `name`, then `exampleId`.

Equal keys keep **`hits` order** (Swift stable `sort`). A warning is still logged with that order.

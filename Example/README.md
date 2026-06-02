# Examples

Sample **DemoPackage** (SwiftPM: OpenAPI-generated `DemoAPI`, Vapor **DemoServer**) and **DemoApp** (SwiftUI in Xcode).

This document is the **reference for this repository’s sample layout**, run commands, and **DemoApp** screenshots.

- **Full docs:** [Documentation index](../docs/README.md) · [Integration](../docs/integration.md) · [Henge](../docs/henge.md)
- **Japanese:** [README_JA.md](README_JA.md)

## Layout

| Path | Role |
| --- | --- |
| [`DemoPackage/`](DemoPackage/) | Swift package: `DemoAPI` target (Types + Client + Kawarimi plugin output), **`DemoAPITests`**, **`DemoServer`** (macOS, Vapor), and **`HengeCli`** (macOS SwiftUI host for `KawarimiConfigView`). |
| [`DemoApp/`](DemoApp/) | SwiftUI sources; open [`DemoApp.xcodeproj`](DemoApp.xcodeproj) in Xcode. |
| [`assets/`](assets/) | PNG screenshots of **DemoApp** (iOS Simulator), embedded below. |

### DemoPackage reference sources

Wiring: [`DemoPackage/Package.swift`](DemoPackage/Package.swift) (`DemoServer` target).

Server entrypoints: [`main.swift`](DemoPackage/Sources/DemoServer/main.swift), [`KawarimiRoutes.swift`](DemoPackage/Sources/DemoServer/KawarimiRoutes.swift).

**DemoServer** registers admin segments from **`KawarimiAdminRoute`** / **`KawarimiAdminPath`**, and **`main.swift`** calls **`DemoServerSpecResponse.validateWireAtStartup()`** before listening. **`GET …/spec`** serves the same **`JSONEncoder`** bytes via **`DemoServerSpecResponse.encodedWireData()`**.

```swift
try DemoServerSpecResponse.validateWireAtStartup()
```

Dynamic mocks use **`KawarimiServerMiddleware`** from the **KawarimiServer** product (`registerHandlers(middlewares:)`). See [Henge](../docs/henge.md).

## Security (sample only)

**`__kawarimi`** admin endpoints have **no authentication**.

**`DemoApp`** sends OpenAPI try-out requests to the **spec-defined base URL** only.

Use only in trusted environments; add your own auth and network controls for real deployments.

This sample is **not** hardened for production.

## Build and run DemoServer

**Use `DemoPackage/` as the current working directory** so `kawarimi.json` is read and written next to the package.

```bash
cd DemoPackage && swift build
swift run DemoServer   # kawarimi.json under DemoPackage/
KAWARIMI_CONFIG=/tmp/kawarimi.json swift run DemoServer
KAWARIMI_CONFIG_WATCH=0 swift run DemoServer   # disable auto-reload on file save
```

**DemoServer** watches `kawarimi.json` by default (`KAWARIMI_CONFIG_WATCH` unset or `1`). Saving the file reloads overrides into the running server.

Override the listen address with `HOST` and `PORT` (default port **8080**). Use `PORT=0` to bind an ephemeral port. After the server is listening, write `http://host:port` to a file with `KAWARIMI_LISTEN_READY_FILE=/path/to/file` or `swift run DemoServer --print-listen-url /path/to/file` (stdout only: `--print-listen-url` with no path).

`DemoAPITests` covers the in-process **`Kawarimi()`** transport path.

### DemoServer HTTP E2E (`DemoServerE2ETests`)

macOS and Linux: a shared **`DemoServer`** subprocess (`PORT=0`, `KAWARIMI_LISTEN_READY_FILE`) exercises real HTTP against **`KawarimiServerMiddleware`** and **`__kawarimi`** admin routes.

```bash
cd DemoPackage && swift test --filter DemoServerE2ETests
```

Coverage matrix and backlog: [Issue #80](https://github.com/novr/Kawarimi/issues/80) (E2E-01–04, 10–11, 20–26 implemented in-repo).

## HengeCli (macOS)

**`HengeCli`** is a small SwiftPM executable in **`DemoPackage`** that runs the same **Kawarimi Henge** UI as the DemoApp tab, without Xcode.

Admin **`baseURL`** is **`KAWARIMI_BASE_URL`** (default `http://127.0.0.1:8080/api`). Same **`KawarimiDemoClientURL`** helper as DemoApp (**DemoSupport**). See [henge.md](../docs/henge.md#hengecli-macos).

```bash
cd DemoPackage && swift run DemoServer   # terminal 1
cd DemoPackage && swift run HengeCli     # terminal 2, macOS only
```

## kawarimi.json (sample)

`KawarimiConfigStore` defaults to `kawarimi.json` in the process working directory. Empty starter file:

```json
{
  "overrides": []
}
```

This repo’s `DemoPackage` includes `kawarimi-generator-config.yaml` next to `openapi.yaml`:

```yaml
handlerStubPolicy: throw
# generateKawarimi: true
# generateHandler: true
# generateSpec: true
```

Example override with response delay (`delayMs` in milliseconds):

```json
{
  "overrides": [
    {
      "path": "/api/greet",
      "method": "GET",
      "statusCode": 200,
      "isEnabled": true,
      "delayMs": 500
    }
  ]
}
```

Override merge / tie-break rules and empty-body normalization: [henge.md](../docs/henge.md#kawarimijson--kawarimi_config).

<a id="try-the-henge-api-demoserver"></a>

## Try the Henge API (DemoServer)

```bash
curl -X POST http://localhost:8080/api/__kawarimi/configure \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":true}'
```

With a **named OpenAPI example** (must match `exampleId` / `responseMap` keys; omit or `null` for the default row):

```bash
curl -X POST http://localhost:8080/api/__kawarimi/configure \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"exampleId":"success","isEnabled":true}'
```

Turn a row **off** but keep it in `kawarimi.json` (`isEnabled: false`):

```bash
curl -X POST http://localhost:8080/api/__kawarimi/configure \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":false}'
```

**Remove** that row entirely (same path/method/status/`exampleId` identity as `configure`; include `exampleId` when the row used a named example):

```bash
curl -X POST http://localhost:8080/api/__kawarimi/remove \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":false}'
```

After editing **`kawarimi.json` on disk**, re-read it into the server (`200` + override JSON; check **`X-Kawarimi-Reload`** — `applied` or `unchanged`):

```bash
curl -i -X POST http://localhost:8080/api/__kawarimi/reload
```

When **calling your API** (not `__kawarimi`), you can send **`X-Kawarimi-Example-Id`** so **`KawarimiServerMiddleware`** picks the matching enabled override among several for the same route.

See [henge.md](../docs/henge.md) (`KawarimiMockRequestHeaders.exampleId`).

Vapor registration pattern: [henge.md](../docs/henge.md) and [`KawarimiRoutes.swift`](DemoPackage/Sources/DemoServer/KawarimiRoutes.swift).

## Client: mock vs this DemoServer

You can use **`Kawarimi()`** (no network) and **`URLSessionTransport()`** from [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) against **`DemoServer`** while developing.

**`DemoApp`** uses **KawarimiHenge** on the Henge tab and the OpenAPI tab for HTTP against a running server.

## Run DemoApp (SwiftUI, macOS / iOS)

1. Start **DemoServer** (above).
2. Open **`DemoApp.xcodeproj`** in Xcode and run the **DemoApp** scheme.

**`DemoApp`** links **`DemoAPI`** from **`DemoPackage`** and **KawarimiCore** / **KawarimiHenge** from the repo root Swift package—**`DemoPackage` has no SwiftUI dependency**.

The sample `openapi.yaml` uses **HTTP** with **`127.0.0.1`** (e.g. `http://127.0.0.1:8080/api`) so clients do not resolve `localhost` to **`::1`** while Vapor listens on **IPv4 loopback** only.

**`DemoApp-Info.plist`** (next to `DemoApp.xcodeproj`, not inside the synced `DemoApp/` folder) sets **NSAppTransportSecurity → NSAllowsLocalNetworking** so ATS allows cleartext to local hosts.

**`DemoApp.entitlements`** enables **App Sandbox** with **`com.apple.security.network.client`** so URLSession can reach local servers (without it, `connectx` fails with *Operation not permitted*).

Point the device or simulator at a host where `openapi.yaml` `servers` matches your running **DemoServer**.

## Screenshots (DemoApp, iOS Simulator)

### Henge — API Explorer tab

Endpoint list with method badges, base URL, search, and **AVAILABLE ENDPOINTS** section.

![DemoApp: Henge API Explorer tab](assets/demo-app-henge-explorer.png)

### OpenAPI — API Execution tab

Try-out style screen: base URL, operation picker, query/body fields, fixed **Run Request** bar, and inline response.

![DemoApp: OpenAPI API Execution tab](assets/demo-app-openapi-execution.png)

## Platform note

**`DemoPackage`** targets **macOS 14+**. Library products in the repo root also declare **iOS 17+** for **DemoApp**.

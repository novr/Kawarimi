# Examples

Sample **DemoPackage** (SwiftPM: OpenAPI-generated `DemoAPI`, Vapor **DemoServer**) and **DemoApp** (SwiftUI in Xcode). This document is the **reference for this repository’s sample layout**, run commands, and **DemoApp** screenshots.

- **Full docs:** [Documentation index](../docs/README.md) · [Integration](../docs/integration.md) · [Henge](../docs/henge.md)
- **Japanese:** [README_JA.md](README_JA.md)

## Layout

| Path | Role |
| --- | --- |
| [`DemoPackage/`](DemoPackage/) | Swift package: `DemoAPI` target (Types + Client + Kawarimi plugin output), **`DemoAPITests`**, and **`DemoServer`** (macOS, Vapor). |
| [`DemoApp/`](DemoApp/) | SwiftUI sources; open [`DemoApp.xcodeproj`](DemoApp.xcodeproj) in Xcode. |
| [`assets/`](assets/) | PNG screenshots of **DemoApp** (iOS Simulator), embedded below. |

### DemoPackage reference sources

Wiring: [`DemoPackage/Package.swift`](DemoPackage/Package.swift) (`DemoServer` target). Server entrypoints: [`main.swift`](DemoPackage/Sources/DemoServer/main.swift), [`KawarimiRoutes.swift`](DemoPackage/Sources/DemoServer/KawarimiRoutes.swift), [`KawarimiInterceptorMiddleware.swift`](DemoPackage/Sources/DemoServer/KawarimiInterceptorMiddleware.swift). **`KawarimiInterceptorMiddleware` is not a KawarimiCore product**—copy or adapt it for your own Vapor app.

## Security (sample only)

**`__kawarimi`** admin endpoints have **no authentication**.

**`DemoApp`** sends OpenAPI try-out requests to the **spec-defined base URL** only. Use only in trusted environments; add your own auth and network controls for real deployments.

This sample is **not** hardened for production.

## Build and run DemoServer

**Use `DemoPackage/` as the current working directory** so `kawarimi.json` is read and written next to the package.

```bash
cd DemoPackage && swift build
swift run DemoServer   # kawarimi.json under DemoPackage/
KAWARIMI_CONFIG=/tmp/kawarimi.json swift run DemoServer
```

**`DemoServer`** passes `pathPrefix` from `KawarimiSpec.meta.apiPathPrefix` (from OpenAPI `servers[0].url`), so the Henge mount matches the spec without a separate env var.

`DemoAPITests` covers the in-process **`Kawarimi()`** transport path.

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
```

Override merge / tie-break rules and empty-body normalization: [henge.md](../docs/henge.md#kawarimijson--kawarimi_config).

<a id="try-the-henge-api-demoserver"></a>

## Try the Henge API (DemoServer)

With default **`pathPrefix` `/api`**:

```bash
curl -X POST http://localhost:8080/api/__kawarimi/configure \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":true}'
```

Vapor registration pattern: [henge.md](../docs/henge.md) and [`KawarimiRoutes.swift`](DemoPackage/Sources/DemoServer/KawarimiRoutes.swift).

## Client: mock vs this DemoServer

You can use **`Kawarimi()`** (no network) and **`URLSessionTransport()`** from [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) against **`DemoServer`** while developing.

**`DemoApp`** uses **KawarimiHenge** on the Henge tab and the OpenAPI tab for HTTP against a running server.

## Run DemoApp (SwiftUI, macOS / iOS)

1. Start **DemoServer** (above).
2. Open **`DemoApp.xcodeproj`** in Xcode and run the **DemoApp** scheme.

**`DemoApp`** links **`DemoAPI`** from **`DemoPackage`** and **KawarimiCore** / **KawarimiHenge** from the repo root Swift package—**`DemoPackage` has no SwiftUI dependency**.

**Server URL** and **API prefix** are fixed to `KawarimiSpec.meta` (`KawarimiExampleConfig` in the app).

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

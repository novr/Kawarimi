# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.0.4] - 2026-04-10

### Added

- **Example/DemoPackage**: **`HengeCli`** executable — macOS SwiftUI host for **`KawarimiConfigView`**, admin **`baseURL`** from generated **`KawarimiSpec.meta`**; **quit** when the last window closes; **activate** the app on launch so text fields work when started from Terminal.

### Fixed

- **KawarimiHenge** (macOS): **TextEditor** / **TextField** input — decorative **`strokeBorder`** overlays use **`allowsHitTesting(false)`**; **`@FocusState`** on content-type and JSON body; JSON editor stays **outside** the outer vertical **`ScrollView`**; drop AppKit search / plain-text wrappers in favor of SwiftUI (**`.searchable`** and **`TextEditor`**).
- **KawarimiHenge** (macOS): **NavigationSplitView** explorer — wrap the sidebar in **`NavigationStack`**, set **`navigationSplitViewColumnWidth`**, use **inline search** in the split layout; compact navigation keeps **`.searchable`** on the stack.
- **KawarimiHenge** (macOS): **Add response** sheet — **`ScrollView`** + **`VStack`** layout instead of **`Form`** section footers that broke spacing on macOS.

### Changed

- **Docs**: **HengeCli** section in **henge.md** / **ja/henge.md**; **Example/README** paragraph breaks; English and Japanese integration samples pin **`from: "1.0.4"`**.

## [1.0.3] - 2026-04-09

### Fixed

- **KawarimiHenge** (macOS): explorer list — endpoint path and related labels could disappear when a row was selected (`List(selection:)` with a custom `listRowBackground`); use explicit AppKit label colors for row text and the search field.
- **KawarimiHenge** (macOS): response JSON editor — `TextEditor` could show light backing under white monospace text; apply the dark `editorFill` behind the field after `scrollContentBackground(.hidden)`.
- **KawarimiHenge** (macOS): search field could not accept focus or typing when hosted in a `List` `safeAreaInset`; stack `ExplorerTopInset` above the `List` instead.

## [1.0.2] - 2026-04-08

### Changed

- **`KawarimiPath`** (**`splitPathSegments`**, **`joinPathPrefix`**, **`aligned(path:pathPrefix:)`**) is the supported API for OpenAPI-style prefixes and persisted route paths; **`OpenAPIPathPrefix`** is deprecated with the same public API as **v1.0.1**, and **`configStoredPath`** uses **`KawarimiPath.aligned`**.
- **Generated `KawarimiSpec.meta.apiPathPrefix`**: when **`servers[0].url`** has no path (e.g. `http://localhost:3001`) or path **`/`** only, emits **`""`** so operation paths match the document root (no implicit **`/api`**).
- **`KawarimiConfigStore`**: default **`pathPrefix`** is **`""`**; prefix is built with **`KawarimiPath`**. Demo **`KawarimiExampleConfig`** / **`OpenAPIExecuteView`** follow the same rules.
- **`OpenAPIPathPrefix.defaultMountPath`** is deprecated — use an explicit prefix or **`KawarimiSpec.meta.apiPathPrefix`**.
- From **1.0.1**, if you relied on **`KawarimiConfigStore(configPath:)`** without **`pathPrefix:`**, pass **`pathPrefix: "/api"`** (or **`OpenAPIPathPrefix.defaultMountPath`**, deprecated) when your API lives under **`/api`**, or use **`KawarimiSpec.meta.apiPathPrefix`** from a regenerated spec.
- Regenerate Kawarimi outputs after upgrade if your OpenAPI server URL has no path segment; refresh persisted **`kawarimi.json`** paths if they no longer match the spec.

## [1.0.1] - 2026-04-08

### Added

- **`LICENSE`** at the repository root (Apache-2.0) so SwiftPM checkouts include a license file for tools such as LicensePlist.

## [1.0.0] - 2026-04-06

### Added

- **`KawarimiJutsu`** library product: OpenAPI loading, YAML config, and Swift source generation (OpenAPIKit / Yams). The **`Kawarimi`** CLI executable now depends on **KawarimiJutsu** instead of embedding that logic in KawarimiCore.
- **`KawarimiFetchedSpec`** and **`KawarimiAPIClient.fetchSpec(as:)`** overload constrained to it, for Henge / admin clients decoding the spec wire JSON.
- **`KawarimiConfigView(client:specType:)`** wiring through **`KawarimiAPIClient`**.
- **`LocalizedError`** on **`KawarimiJutsuError`**, **`KawarimiConfigStoreError`**, and **`MockOverride.InvalidMethodStringError`**.
- **`KawarimiJutsuError.idiomaticNamingInvariantViolated`** when idiomatic naming hits an internal invariant (generation fails with `throws` instead of `preconditionFailure`).
- **`KawarimiConfigStore`**: OSLog warning when `kawarimi.json` exists but JSON decode fails; overrides start empty.

### Changed

- **`KawarimiPlugin`**: resolves **`openapi.yaml`** from the Swift target **root** (`SwiftSourceModuleTarget.directoryURL`), aligned with **swift-openapi-generator**. Config files beside the spec are unchanged.
- **`KawarimiNamingStrategy.swiftOperationTypeName(forOperationId:)`** and **`swiftOperationMethodName(forOperationId:)`** are now **`throws`**.
- **`KawarimiAPIClient.configure(path:method:…)`** throws **`MockOverride.InvalidMethodStringError`** when the method string cannot be parsed (instead of failing later).

### Fixed

- **Henge**: **Reset All** failures are surfaced via **`errorMessage`** (`performResetAll` is `async throws`; no silent `try?`).

### Removed

- **`KawarimiCoreExports.swift`**: **`@_exported import HTTPTypes`** removed. Targets that compile generated **`KawarimiSpec.swift`** (or any file using **`HTTPRequest.Method`**, etc.) must declare a **direct** SwiftPM dependency on the **`HTTPTypes`** product (see [integration.md](docs/integration.md)).

### Migration from 0.11.x

1. **SwiftPM**  
   - Bump the package pin to **`from: "1.0.0"`** (or an exact version). The published Git tag is **`v1.0.0`**.  
   - Add **`KawarimiJutsu`** only if you call generation APIs or link the **`Kawarimi`** tool from code; typical apps need **KawarimiCore** / **KawarimiHenge** / plugin only.

2. **`openapi.yaml` location**  
   - Ensure **`openapi.yaml`** lives in the **Swift target root** (same directory SwiftPM uses for that target). Layouts that relied on “first source file’s parent” may need to move the file.

3. **`HTTPTypes`**  
   - Add **`.product(name: "HTTPTypes", package: "swift-http-types")`** to any target that **`import HTTPTypes`** (including generated spec sources). It is not implied by **`KawarimiCore`** alone.

4. **API**  
   - Replace **`MockOverride`** string-based **`init`** with **`init?(…)`** or use **`KawarimiAPIClient.configure(path:…)`** which throws on bad methods.  
   - Any custom callers of **`swiftOperationTypeName` / `swiftOperationMethodName`** must **`try`**.  
   - **Henge**: prefer **`KawarimiConfigView(client:specType:)`** with your generated **`SpecResponse`**.

[1.0.4]: https://github.com/novr/Kawarimi/releases/tag/v1.0.4
[1.0.3]: https://github.com/novr/Kawarimi/releases/tag/v1.0.3
[1.0.2]: https://github.com/novr/Kawarimi/releases/tag/v1.0.2
[1.0.1]: https://github.com/novr/Kawarimi/releases/tag/v1.0.1
[1.0.0]: https://github.com/novr/Kawarimi/releases/tag/v1.0.0

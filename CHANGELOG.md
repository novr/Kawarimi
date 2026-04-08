# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Git tags** use a **`v`** prefix (e.g. **`v1.0.0`**), consistent with GitHub Releases. **SwiftPM** dependency pins use the semver **without** `v` (e.g. `from: "1.0.0"` — SwiftPM strips a leading `v` when resolving tags).

## [Unreleased]

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

[1.0.1]: https://github.com/novr/Kawarimi/releases/tag/v1.0.1
[1.0.0]: https://github.com/novr/Kawarimi/releases/tag/v1.0.0

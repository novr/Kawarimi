# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Added

- **KawarimiValidate** macOS universal binary on GitHub Releases (`kawarimi-validate_{version}_darwin.tar.gz`, `checksums.txt`).
- **Homebrew:** `brew install novr/taps/kawarimi-validate` via [novr/homebrew-taps](https://github.com/novr/homebrew-taps) (release workflow dispatches formula update).

### Changed

- **KawarimiValidate** CLI: `--version` reports release tag (local/PR stub: `dev`).

## [3.3.0] - 2026-07-06

### Added

- **KawarimiValidate** — fail CI on structural mock/scenario JSON issues that runtime only warns about ([#182](https://github.com/novr/Kawarimi/issues/182)).
- **skills/kawarimi-user-mock-and-scenario-format** — single agent SSOT so mock JSON stays aligned with runtime contracts ([#182](https://github.com/novr/Kawarimi/issues/182)).
- **Example**: committed **`kawarimi-scenarios.json`** two-step **`GET /api/greet`** sample and matching **`kawarimi.json.example`** fixed **`rowId`** overrides ([#176](https://github.com/novr/Kawarimi/issues/176)).
- **Example**: one-step **`POST /api/items` → 400** scenario fixture (`createItem_validation`) and E2E (`scenarioCreateItemValidationOneStepError`).
- **Example**: DemoServer E2E tests for scenario orchestration header timelines ([#177](https://github.com/novr/Kawarimi/issues/177)), including **`X-Kawarimi-Id`** omission restarting at **`initial`** after a terminal step.
- **Example**: **`KawarimiClientOrchestrationMiddleware`** integration E2E against **DemoServer** (`clientScenarioGreetTwoStepTimeline` in **`DemoServerE2ETests`**); Swift client snippet in **Example/README**.
- **Henge**: detail column shows persisted override **`rowId`** with **Copy** for hand-editing `kawarimi-scenarios.json` ([#178](https://github.com/novr/Kawarimi/issues/178)).

### Changed

- **KawarimiValidate**: missing scenarios file is fatal when `--scenarios` or `KAWARIMI_SCENARIOS_CONFIG` is set; default path beside config may still be absent (overrides-only).
- **CI / structure:** merge internal **`KawarimiPluginSupport`** into **`KawarimiJutsu`** (`KawarimiGeneratorOutputOptions`, **`KawarimiGeneratorConfigLineParser`**); split tests into **`KawarimiJutsuTests`** and **`KawarimiHengeCoreTests`** (Henge logic was under **`Tests/KawarimiCoreTests/Henge/`**).

### Docs

- **skills/kawarimi-user-mock-and-scenario-format**: authoring SSOT (validate prerequisites, `rowId` rules); **integration.md** / **ja/integration.md** hold `npx skills` install; henge links here instead of duplicating content.
- **henge.md** / **ja/henge.md**: Henge automated tests now **`KawarimiHengeCoreTests`** (`Tests/KawarimiHengeCoreTests/`).

## [3.2.0] - 2026-06-26

### Added

- **KawarimiCore**: scenario orchestration — **`kawarimi-scenarios.json`**, **`KawarimiScenarioResolver`**, **`KawarimiScenarioHeaders`**, **`KawarimiScenarioValidation`** (load warnings), and **`KawarimiConfigStore.scenarios()`** / reload integration ([#166](https://github.com/novr/Kawarimi/issues/166)).
- **KawarimiServer**: **`KawarimiServerMiddleware`** resolves scenario headers before **`X-Kawarimi-Example-Id`** ([#167](https://github.com/novr/Kawarimi/issues/167)).
- **KawarimiClient**: **`KawarimiClientOrchestrationMiddleware`** tracks per-scenario **`X-Kawarimi-Id`** state from **`X-Next-Kawarimi-Id`** ([#168](https://github.com/novr/Kawarimi/issues/168)).

### Changed

- **KawarimiConfigStore**: file watch now monitors **`kawarimi-scenarios.json`** as well as **`kawarimi.json`**; **`scenariosPath`** rejects `..` like **`configPath`**. Scenario path: init `scenariosPath:` → **`KAWARIMI_SCENARIOS_CONFIG`** → default next to `kawarimi.json`.

### Docs

- **henge.md** / **ja/henge.md** / **Example README** (EN/JA): scenario orchestration (`rowId` references, headers, server/client middleware).

## [3.1.0] - 2026-06-19

### Added

- **KawarimiCore**: optional **`MockOverride.rowId`** (UUID) for stable row identity; `KawarimiConfigStore.configure` now guarantees server-side rowId assignment when missing.

### Changed

- **KawarimiCore**: override identity for `configure` / `removeOverride` now checks **`rowId` first**, then uses legacy `path + method + statusCode + exampleId` matching only when the incoming row omits `rowId` (deterministic first-hit fallback).
- **KawarimiHengeCore**: `removeIdentity` now carries persisted `rowId` and row comparisons use rowId-first behavior during staged migration.

### Docs

- **henge.md** / **ja/henge.md** / **mock-json.md** / **ja/mock-json.md** / **Example README** (EN/JA): documented rowId-first identity, legacy fallback compatibility, and migration direction away from fallback.

## [3.0.0] - 2026-06-05

### Added

- **KawarimiHenge**: **Reload kawarimi.json** in the explorer chrome — **`KawarimiAPIClient.reload()`** returns **`KawarimiConfigReloadResponse`** (outcome + overrides in one call) and shows **`applied`** / **`unchanged`** under the button ([#130](https://github.com/novr/Kawarimi/issues/130)).
- **KawarimiCore**: **`KawarimiConfigReloadResponse`** — reload outcome plus post-reload override list from **`POST …/__kawarimi/reload`**.
- **KawarimiCore**: **`configureAndFetchOverrides`**, **`removeAndFetchOverrides`**, and **`resetAndFetchOverrides`** on **`KawarimiAPIClient`** — aliases for mutation methods that now return overrides in the response body ([#147](https://github.com/novr/Kawarimi/issues/147)).
- **KawarimiHenge**: operation-level cleanup action in detail header to remove all **disabled** override rows for the selected operation in one step ([#129](https://github.com/novr/Kawarimi/issues/129)).

### Changed

- **KawarimiHenge**: Save / Del / Reset all use admin mutation response bodies — no follow-up **`GET …/status`** after **`configure`** / **`remove`** / **`reset`** ([#147](https://github.com/novr/Kawarimi/issues/147)). **Reset all** still bumps **`specLoadID`** so stashed dirty drafts are cleared.

### Docs

- **henge.md** / **integration.md** (EN/JA): admin error responses (DemoServer reference); **`2.7.0 → next release`** admin migration.
- **henge-detail-column-regression.md** (EN/JA): post-#120 regression checks for one-step **Del** and **inactive chip + Save** behavior ([#127](https://github.com/novr/Kawarimi/issues/127)).
- **henge.md** / **ja/henge.md**: documented operation-level bulk remove of disabled overrides ([#129](https://github.com/novr/Kawarimi/issues/129)).

### Breaking

- **Admin HTTP**: **`POST …/__kawarimi/reload`** now returns **`200`** with a JSON override array (same as **`GET …/status`**) and **`X-Kawarimi-Reload: applied|unchanged`**, instead of **`204 No Content`**. **`KawarimiAPIClient.reload()`** returns **`KawarimiConfigReloadResponse`** instead of **`KawarimiConfigReloadResult`**. Custom admin servers must encode overrides after **`reloadFromDisk()`**.
- **Admin HTTP**: **`POST …/__kawarimi/configure`**, **`POST …/remove`**, and **`POST …/reset`** now return **`200`** with a JSON override array (same as **`GET …/status`**) instead of empty **`200`**. **`KawarimiAPIClient.configure`**, **`removeOverride`**, and **`reset`** return **`[MockOverride]`** instead of **`Void`**. Custom admin servers must encode **`store.overrides()`** after each mutation ([#147](https://github.com/novr/Kawarimi/issues/147)).

## [2.7.0] - 2026-06-02

### Added

- **KawarimiCore**: **`KawarimiConfigFileWatcher`** and **`KawarimiConfigStore/startFileWatchIfEnabled()`** — reload `kawarimi.json` when the config file changes on disk (debounced; macOS vnode, Linux inotify). Opt out with **`KAWARIMI_CONFIG_WATCH=0`** (unset or **`1`** → enabled). **DemoServer** enables watch at startup ([#141](https://github.com/novr/Kawarimi/pull/141)).
- **KawarimiCore**: **`KawarimiAdminRoute`**, **`adminURL(baseURL:route:)`**, and **`KawarimiAdminSpecWire.validate(_:)`** — shared admin HTTP route contract and spec wire decode validation ([#144](https://github.com/novr/Kawarimi/pull/144)).
- **Example**: **DemoServer** admin route segments from **`KawarimiAdminRoute`**; shared **`DemoServerSpecResponse`** wire builder; startup and **`GET …/spec`** both serve **`JSONEncoder`** output validated by **`KawarimiAdminSpecWire`**; E2E asserts HTTP spec bytes decode as **`HengeSpecSnapshot`**; admin success statuses follow **`KawarimiAdminRoute.successStatusCode`** ([#144](https://github.com/novr/Kawarimi/pull/144)).
- **Example**: expanded **DemoServerE2ETests** for admin **`reload`**, legacy **`remove`**, and **`KawarimiAdminRoute`** paths ([#143](https://github.com/novr/Kawarimi/pull/143)).

### Migration from 2.6.0

1. **SwiftPM** — Bump pin to **`from: "2.7.0"`**.
2. **Server** — Optional: call **`await store.startFileWatchIfEnabled()`** after **`KawarimiConfigStore`** init so disk edits to **`kawarimi.json`** apply without restart (disable with **`KAWARIMI_CONFIG_WATCH=0`**).
3. **Server** — Optional: register admin segments via **`KawarimiAdminPath`** / **`KawarimiAdminRoute`** and validate spec wire at startup (**`KawarimiAdminSpecWire.validate`**) — see [integration.md](docs/integration.md) and [Example/README.md](Example/README.md).
4. **Henge / client-only** — No required API changes unless you adopt the new admin route helpers.

## [2.6.0] - 2026-05-31

### Breaking

- **KawarimiHenge**: **`KawarimiConfigView(client:specType:)`** removed — use **`KawarimiConfigView(client:)`** only. Henge UI targets no longer need to link a host-generated **`SpecResponse`**; spec and endpoints come from **`GET …/__kawarimi/spec`** via **`HengeSpecSnapshot`** ([#120](https://github.com/novr/Kawarimi/issues/120), [#132](https://github.com/novr/Kawarimi/pull/132), [#133](https://github.com/novr/Kawarimi/pull/133)).
- **KawarimiHenge**: **Del (−)** with a matching **saved** override row now always calls **`POST …/__kawarimi/remove`** in one step. The previous two-step flow (Del while mock **on** → **`configure`** with **`isEnabled: false`** and body preserved, then Del again to **`remove`**) is removed. To turn a mock off but **keep** the row in **`kawarimi.json`**, use an **inactive chip + Save**, not **Del** ([#120](https://github.com/novr/Kawarimi/issues/120), [#136](https://github.com/novr/Kawarimi/pull/136)). **Del** prevents **Del-induced** disabled-row buildup; **Save** with **`isEnabled: false`** can still grow the file if you keep disabled presets.

### Added

- **KawarimiCore**: **`HengeSpecSnapshot`** and **`KawarimiAPIClient.fetchHengeSpec()`** — wire decode for Henge without a generated **`SpecResponse`** ([#132](https://github.com/novr/Kawarimi/pull/132)).
- **Example**: **`DemoSupport`** / **`KawarimiDemoClientURL`** — shared admin **`baseURL`** for DemoApp and **HengeCli** (`KAWARIMI_BASE_URL`, default `http://127.0.0.1:8080/api`) ([#133](https://github.com/novr/Kawarimi/pull/133)).

### Changed

- **KawarimiHenge**: **`meta`**, **`endpoints`**, and the displayed server URL are loaded from the server spec snapshot after fetch (not from linked **`KawarimiSpec.meta`**) ([#133](https://github.com/novr/Kawarimi/pull/133)).
- **KawarimiHengeCore**: **`DisableMockPlanner`** — saved row → **`remove`**; unsaved draft only → local clear toward Spec (no HTTP) ([#136](https://github.com/novr/Kawarimi/pull/136)).
- **KawarimiHengeCore**: **Spec** chip **Save** / **Reset** — when the draft is Spec-only shaped, **`remove`** a matching stored default row instead of upserting a disabled placeholder (avoids spec-follow ghost rows in `kawarimi.json`). Supplemental chips hide disabled no-body rows for documented status codes ([#134](https://github.com/novr/Kawarimi/pull/134)).
- **KawarimiHengeCore**: **Del** — **`storedOverrideForDel`** matches legacy rows saved without `exampleId` whose body matches a named OpenAPI example; **`removeIdentity`** uses the row’s persisted **`path`** / **`exampleId`** on **`POST …/remove`** ([#134](https://github.com/novr/Kawarimi/pull/134)).
- **Example**: **HengeCli** no longer depends on **DemoAPI** ([#133](https://github.com/novr/Kawarimi/pull/133)).
- **Dependencies**: [Yams](https://github.com/jpsim/Yams) 6.2.1 → 6.2.2 ([#138](https://github.com/novr/Kawarimi/pull/138)); [swift-argument-parser](https://github.com/apple/swift-argument-parser) 1.7.1 → 1.8.1 ([#139](https://github.com/novr/Kawarimi/pull/139)).

### Docs

- **henge.md** / **ja/henge.md**: Henge SSoT, **`KawarimiConfigView(client:)`**, HengeCli base URL, **Del** semantics, Spec **Save**/**Reset** → **`remove`**, OpenAPI chips vs saved rows ([#136](https://github.com/novr/Kawarimi/pull/136), [#134](https://github.com/novr/Kawarimi/pull/134)).

### Migration from 2.5.0

1. **SwiftPM** — Bump pin to **`from: "2.6.0"`**.
2. **Henge UI** — Replace **`KawarimiConfigView(client:specType: SpecResponse.self)`** with **`KawarimiConfigView(client: KawarimiAPIClient(baseURL: …))`**. Pass only the admin **`baseURL`** (must reach **`…/__kawarimi/*`**). Remove **`import`** / SPM dependency on your generated API module from the Henge-only app target if it was only used for **`SpecResponse`**.
3. **Del workflow** — Users who relied on **Del** to **turn off** an active mock while **keeping** the row must switch to **inactive chip + Save**. **Del** now **deletes** the saved row for the current chip (or clears an unsaved draft locally).
4. **Example / HengeCli** — Optional **`KAWARIMI_BASE_URL`** env var; default matches Demo **`openapi.yaml`** servers entry.

## [2.5.0] - 2026-05-27

### Added

- **KawarimiSpec** / **`SpecEndpointProviding`**: optional OpenAPI operation **parameters** (path, query, header) on generated endpoints — merged path-item + operation, operation wins; `schemaType` when a single primary JSON Schema type applies ([#74](https://github.com/novr/Kawarimi/issues/74)).
- **KawarimiHenge**: read-only **PARAMETERS** section in the endpoint detail column.

### Changed

- **KawarimiCore**: `SpecParameter`, `SpecParameterLocation`, and `SpecParameter.merge` for shared generation and UI.

### Fixed

- **KawarimiHenge**: keep the detail-column toolbar visible when JSON content is tall ([#117](https://github.com/novr/Kawarimi/pull/117)).
- **KawarimiHenge**: fix JSON editor line-number view explosion ([#122](https://github.com/novr/Kawarimi/pull/122)).

## [2.4.0] - 2026-05-25

### Fixed

- **KawarimiJutsu**: unify OpenAPI `date-time` / `date` mock JSON (ISO8601 strings, no empty `""` fallback) and `KawarimiHandler` decode stubs via shared `_kawarimiStubJSONDecoder()` ([#112](https://github.com/novr/Kawarimi/issues/112)). Mock JSON date synthesis emits the same stderr fallback warnings as handler literals when examples are missing or unparseable.

### Added

- **KawarimiHenge**: read-only **Security** section in the endpoint detail column — effective OpenAPI `security` (OR across requirements, AND within) and referenced scheme definitions from `securitySchemeCatalog` ([#108](https://github.com/novr/Kawarimi/issues/108)).
- **KawarimiHenge**: read-only **Tags** on endpoint list rows and in the detail column; explorer search matches OpenAPI operation `tags` ([#56](https://github.com/novr/Kawarimi/issues/56)).
- **KawarimiHenge**: **`operationId`** in the endpoint detail column; **`meta.description`** under the explorer list header; **selected OpenAPI response** `summary` / `description` when a numbered chip is selected.

### Changed

- **`KawarimiFetchedSpec`**: optional **`securitySchemeCatalog`**; generated **`SpecResponse`** maps wire **`securitySchemes`**.

## [2.3.1] - 2026-05-21

### Changed

- **CI:** Swift ubuntu workflows cache SwiftPM `.build` and global artifacts via `actions/cache` keyed on `Package.resolved` ([#106](https://github.com/novr/Kawarimi/pull/106)).
- **CI / structure:** Henge explorer logic in **`Sources/KawarimiHengeCore`** / target **`KawarimiHengeCore`**; SwiftUI in **`Sources/KawarimiHenge`** / **`KawarimiHenge`**. Tests in **`Tests/KawarimiCoreTests/Henge/`** run on ubuntu CI ([#83](https://github.com/novr/Kawarimi/issues/83), [#104](https://github.com/novr/Kawarimi/pull/104)).
- **CI**: drop PR **`kawarimi-perf`** job (display-only `[kawarimi-perf]` lines; use **`performance.yaml`** `workflow_dispatch` or local **`Scripts/performance/`** for measurement) ([#105](https://github.com/novr/Kawarimi/pull/105)).

## [2.3.0] - 2026-05-20

### Added

- **KawarimiSpec** / **`SpecResponse`**: OpenAPI `components.securitySchemes` and per-endpoint effective `security` (global inheritance, `security: []` override, OR/AND semantics). Emits `apiKey` / `http` fields and `openIdConnectURL`; oauth2 flows are not expanded ([#102](https://github.com/novr/Kawarimi/pull/102)).
- **KawarimiCore**: `SpecSecuritySchemeProviding`, `SpecSecurityRequirementProviding`, `SpecScopedSecuritySchemeProviding`; `SpecEndpointProviding.security`.
- **Example**: Demo `openapi.yaml` adds sample `securitySchemes` and operation-level `security` overrides.

## [2.2.2] - 2026-05-20

### Added

- **Example**: `openapi.yaml` greet response adds named `examples` (`success` / `formal`).
- **Example**: **`DemoServerE2ETests`** — E2E-10/11 (items via middleware + `responseMap`), E2E-20–26 (Henge admin API) ([#80](https://github.com/novr/Kawarimi/issues/80)).

### Docs

- **`AGENTS.md`**: patch releases do not update **`docs/integration.md`**; trim redundant integration migration notes.

## [2.2.1] - 2026-05-20

### Fixed

- **Release workflow** (`.github/workflows/release.yaml`): run steps with **bash** in the `swift:6.2-noble` container ([#92](https://github.com/novr/Kawarimi/pull/92)); create the source archive **before** `swift test` ([#93](https://github.com/novr/Kawarimi/pull/93)); write the archive **outside** the workspace root ([#94](https://github.com/novr/Kawarimi/pull/94)).

### Changed

- **Release workflow**: on tag **`v*`** push, set the GitHub Release **Description** from the matching **`CHANGELOG.md`** section via **`octivi/release-notes-from-changelog`** ([#91](https://github.com/novr/Kawarimi/issues/91)).

### Docs

- **`AGENTS.md`** — CHANGELOG structure contract, Conventional Commits / **`chore(release)`**, and two-phase release flow ([#91](https://github.com/novr/Kawarimi/issues/91)).

## [2.2.0] - 2026-05-19

### Added

- **KawarimiCore**: **`KawarimiConfigStore.reloadFromDisk()`** and **`POST …/__kawarimi/reload`** (`204` + **`X-Kawarimi-Reload: applied|unchanged`**) to re-read runtime **`kawarimi.json`** without restart ([#77](https://github.com/novr/Kawarimi/issues/77)).
- **KawarimiCore**: **`matchingEnabledOverridesForOperation`** and **`primaryEnabledOverrideForOperation`** — shared override selection and tie-break for server middleware and Henge ([#78](https://github.com/novr/Kawarimi/issues/78)).
- **KawarimiCore** / **KawarimiHenge**: optional **`delayMs`** on mock overrides (normalized 0–60_000 ms) ([#53](https://github.com/novr/Kawarimi/issues/53)).
- **KawarimiServer**: **`KawarimiServerMiddleware`** honors **`delayMs`** before returning a mock response.
- **Kawarimi CLI**: **`--help`** / **`-h`** and **`--version`** via [swift-argument-parser](https://github.com/apple/swift-argument-parser) ([#71](https://github.com/novr/Kawarimi/issues/71)).
- **Release workflow** (`.github/workflows/release.yaml`): on tag **`v*`** push, writes **`BuildInfo.version`** from **`git describe --tags`**, runs **`swift test`**, and attaches **`kawarimi-vX.Y.Z-source.tar.gz`** ([#71](https://github.com/novr/Kawarimi/issues/71)).

### Changed

- **KawarimiHenge**: explorer primary and enabled override lists use the Core APIs above; **`sortedForOverrideTieBreak`** (alias **`sortedForInterceptorTieBreak`**) ([#78](https://github.com/novr/Kawarimi/issues/78)).
- **KawarimiPlugin** / **KawarimiJutsu**: shared **`KawarimiGeneratorOutputOptions`** validation and output file names via **`KawarimiPluginSupport`** ([#73](https://github.com/novr/Kawarimi/issues/73)).
- **Kawarimi CLI**: **`--version`** reports **`git describe --tags`** (e.g. **`v2.2.0`**) in release archives; committed **`Generated.swift`** stub is **`dev`** for local and PR CI ([#71](https://github.com/novr/Kawarimi/issues/71)).

### Docs

- **henge.md** / **ja/henge.md** — override matching **Product rules** ([#78](https://github.com/novr/Kawarimi/issues/78)).

## [2.1.0] - 2026-05-19

### Added

- **KawarimiServer**: **`KawarimiServerMiddleware`** (`ServerMiddleware`) for Henge runtime overrides on `registerHandlers(middlewares:)` ([#75](https://github.com/novr/Kawarimi/issues/75)).
- **KawarimiCore**: **`MockOverrideRequestMatching`**, **`KawarimiDynamicMockResponseResolver`**, **`KawarimiRequestPath`** — shared override selection and response resolution for server middleware and Henge.

### Changed

- **Example `DemoServer`**: dynamic mocks via **`KawarimiServerMiddleware`** instead of Vapor-global **`KawarimiInterceptorMiddleware`** (removed).

## [2.0.5] - 2026-05-18

### Added

- **KawarimiJutsu** / **KawarimiPlugin**: **`kawarimi-generator-config.yaml`** flags **`generateKawarimi`**, **`generateHandler`**, **`generateSpec`** (default **`true`**) for selective codegen ([#54](https://github.com/novr/Kawarimi/issues/54), [#68](https://github.com/novr/Kawarimi/pull/68)).
- **KawarimiSpec** / **`SpecEndpointProviding`**: optional OpenAPI operation **`tags`** on generated endpoints ([#56](https://github.com/novr/Kawarimi/issues/56), [#69](https://github.com/novr/Kawarimi/pull/69)). Omitted when the operation has no tags (`nil`, not `[]`).

## [2.0.4] - 2026-05-14

### Added

- **Kawarimi CLI** / **KawarimiJutsu**: **`generateKawarimiHandlerSource` `warnings`** — one **`[kawarimi] warning:`** line per operation omitted from generated transport, handler, and spec (missing or empty **`operationId`**), emitted from the same **`generateHandlerMethods`** pass as handler stub warnings; CLI **`stderr`** unchanged ([#55](https://github.com/novr/Kawarimi/issues/55), [#62](https://github.com/novr/Kawarimi/pull/62)).

## [2.0.3] - 2026-05-14

### Fixed

- **KawarimiJutsu**: **`$ref`** cycles in **components** schemas are detected while resolving references for mock JSON and handler literal generation; cyclic refs yield **`{}`** for transport/spec mocks and **`handlerGenerationUnsupported`** for literal stubs ([#51](https://github.com/novr/Kawarimi/issues/51), [#58](https://github.com/novr/Kawarimi/pull/58)).
- **KawarimiJutsu**: **`allOf`** object branches for schema-derived mock JSON — shallow-merge top-level object keys (later members override earlier); non-object branches ignored; empty merge falls back to the first subschema ([#50](https://github.com/novr/Kawarimi/issues/50), [#58](https://github.com/novr/Kawarimi/pull/58)).
- **KawarimiGeneratorConfigFileYAML**: invalid **`kawarimi-generator-config`** YAML decode logs one **stderr** line (path and error) instead of failing silently, then continues without a **`handlerStubPolicy`** override ([#52](https://github.com/novr/Kawarimi/issues/52), [#58](https://github.com/novr/Kawarimi/pull/58)).

### Changed

- **Kawarimi CLI**: **`[kawarimi-perf]`** phased timings on **stderr** only when **`KAWARIMI_PERF=1`** ([#49](https://github.com/novr/Kawarimi/pull/49)). **`ci.yaml`** perf job and **`Scripts/performance/`** set the variable for measurement.

### Added

- **`AGENTS.md`** — contributor and agent guidelines ([#59](https://github.com/novr/Kawarimi/pull/59)).
- **CI**: **`ci.yaml`** — skip **macOS** **`swift test`** / **`kawarimi-perf-report`** when changes touch only paths outside code, tests, Example, Scripts, and workflow filters (documentation-only PRs) ([#60](https://github.com/novr/Kawarimi/pull/60)).

## [2.0.2] - 2026-05-12

### Added

- **Kawarimi CLI**: phased timings on **stderr** as **`[kawarimi-perf]`** (**`setup`**, **`load`**, generation phases, **`total`**). Each generation phase logs **`skipped`** when the output file was unchanged ([#45](https://github.com/novr/Kawarimi/pull/45)).
- **KawarimiCore**: **`GeneratedFileWriter.writeIfChanged`** — compare-before-write helper that preserves output file **mtime** when content is unchanged, reducing unnecessary recompilation in incremental builds ([#42](https://github.com/novr/Kawarimi/issues/42), [#45](https://github.com/novr/Kawarimi/pull/45)). Uses file-size early exit and **`Data`** comparison; throws **`OutputDirectoryMissing`** (works in Release builds).
- **Scripts/performance**: **`generate_openapi_fixture.py`**, **`run_kawarimi_fixture.sh`**, **`incremental-build.sh`** (DemoPackage), and **`Scripts/performance/README.md`** for local measurement.
- **CI**: **`ci.yaml`** — **`kawarimi-perf-report`** on **pull_request** writes small-fixture output under **`kawarimi-perf-out`** and posts or updates **`[kawarimi-perf]`** as a PR comment; **`performance.yaml`** (**`workflow_dispatch`** only) runs the same fixture by default or **`incremental_demo`** runs **`incremental-build.sh --clean`** only (heavy).

## [2.0.1] - 2026-04-24

### Fixed

- **KawarimiJutsu**: **`KawarimiHandler`** literal-init stubs for JSON fields with **`format: date-time`** or **`format: date`** now emit **`Foundation.Date`** (`Date(timeIntervalSince1970:…)`) instead of Swift string literals, matching **swift-openapi-generator** output ([#35](https://github.com/novr/Kawarimi/issues/35)).
- When the OpenAPI **`example`** is missing or cannot be parsed at codegen time, the stub uses **`Date(timeIntervalSince1970: 0)`** and appends a **Kawarimi warning** (includes **operationId** and schema path).

## [2.0.0] - 2026-04-24

### Breaking

- **KawarimiJutsu**: **`loadOpenAPISpec`** returns **`OpenAPIKit.OpenAPI.Document`** (not **`OpenAPIKit30.OpenAPI.Document`** alone). Call sites that fixed the result to **`OpenAPIKit30`** types must **`import OpenAPIKit`** and update annotations.
- **KawarimiJutsuError**: **`specFileInvalidEncoding`** removed.
- **KawarimiGeneratorConfigFileYAML**: **`handlerStubPolicyBesideOpenAPIYAML`** is now **`throws`** and takes optional **`targetNameForErrorMessages`**; callers must use **`try`**.
- **`openapi-generator-config.yaml`** or **`.yml`** is **required** beside the OpenAPI document (zero or multiple files are errors for **`KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML`** and for **KawarimiPlugin**).
- **KawarimiPlugin**: among the target’s **`sourceFiles`**, **exactly one** of **`openapi.yaml`**, **`openapi.yml`**, or **`openapi.json`** is required (zero or multiple is an error). **Optional** **`kawarimi-generator-config`**: **at most one** among **`sourceFiles`**; two or more is an error. Layouts that relied only on a root **`openapi.yaml`** without listing files, or without **`openapi-generator-config`**, must be updated.

### Changed

- **KawarimiJutsu**: **`loadOpenAPISpec`** decodes with **Yams `YAMLDecoder`** from **`Data`** (YAML and JSON). Supports **OpenAPI 3.0.x** (via **OpenAPIKit30** + **OpenAPIKitCompat**), **3.1.x**, and **3.2.0** with version branching aligned to **swift-openapi-generator** **YamsParser**.
- **KawarimiPlugin** / **KawarimiJutsu**: **`FileError`**-style lines for OpenAPI document and **`openapi-generator-config`** discovery match upstream wording; strings live in **`OpenAPIGeneratorFileErrorMessages.swift`**, **symlinked** from **`Plugins/KawarimiPlugin/`** into the same source file as **KawarimiJutsu**. **`KawarimiPluginError.incompatibleTarget`** names the **Kawarimi** plugin (non–Swift targets).
- **`kawarimi-generator-config`**: duplicate messages are defined in **`KawarimiGeneratorConfigSourceMessages.swift`**, also **symlinked** into **`Plugins/KawarimiPlugin/`**. The **Kawarimi** CLI enforces **at most one** file beside the OpenAPI path.

## [1.1.2] - 2026-04-22

### Fixed

- **SwiftPM**: **`swift test --package-path Example/DemoPackage/`** resolves with the root package again — **OpenAPIKit** remains **3.9.x** (compatible with **swift-openapi-generator**); **Yams** **6.2.1**.

### Changed

- **Repo**: **Dependabot** (`.github/dependabot.yml`) — **Swift** **`/`** and **`Example/DemoPackage`**, **GitHub Actions**; **weekly**, limit **5**, **`groups`** (Swift **patch**; Actions **all**), PR **`labels`** (**`dependencies`**, **`swift`**, **`dependencies:package`**, **`dependencies:demo`**, **`github_actions`**); root Swift adds **`ignore`** for **openapikit** **semver-major** updates (they cannot resolve with **swift-openapi-generator** in the same graph as **Example/DemoPackage**).
- **CI**: **GitHub Actions** — parallel **`swift test`** on **`macos-26`** (**`kawarimi`**, **`demo-package`**) with the image **default Xcode**; **`swift-test`** (**Swift Test**, **`needs`** both).
- **Example** / **Git**: **`Example/**/swiftpm/Package.resolved`** (Xcode workspace and embedded **`project.xcworkspace`** SwiftPM locks) is no longer tracked — **`.gitignore`** ignores those paths so Xcode can regenerate them per clone. The root **`Package.resolved`** for the Swift package remains versioned.
- **Dependencies** (root): **Yams** **6.2.1**.
- **GitHub Actions**: **actions/checkout** v6 (Dependabot **actions** group).

## [1.1.1] - 2026-04-15

### Fixed

- **KawarimiJutsu**: **`KawarimiHandler`** stubs for **`application/json`** responses fall back to **JSON decode** (the same payload as **`mockJSONBodyFromJSONMediaType`**) when **`swiftInitializerForSchema`** cannot synthesize a literal — shapes such as **`enum`**, **`allOf`**, and **`oneOf`** no longer yield **`fatalError`** stubs for JSON success bodies.
- **`handlerStubPolicy`**: **`fatalError`** remains for responses that still cannot be stubbed (for example non-JSON success bodies); covered by the **XML** success OpenAPI fixture tests.

### Changed

- **Docs**: **mock-json.md** / **ja**, **integration.md** / **ja**, **README** / **README_JA**, **docs/README.md** / **ja/README.md** — document **`KawarimiHandler`** default stubs: **JSON decode fallback** when a literal initializer cannot be generated; **`handlerStubPolicy`** only traps **`fatalError`** for operations that still cannot be stubbed.

## [1.1.0] - 2026-04-10

### Removed

- **KawarimiCore**: **`OpenAPIPathPrefix`** (deprecated since **1.0.2**). Use **`KawarimiPath`** (`splitPathSegments`, `joinPathPrefix`, `aligned(path:pathPrefix:)`). Replace **`configStoredPath(path:pathPrefix:)`** with **`KawarimiPath.aligned`**. For **`normalizedPrefix`** / **`stubServerURL`**, build paths with **`KawarimiPath`** and **`URLComponents`** yourself (there is no implicit **`/api`** default on empty input).

### Fixed

- **KawarimiHenge**: Opening an endpoint from the list when a **disabled default** stored row (e.g. **200** off) appears **before** the **enabled primary** (e.g. **503** custom) no longer loads the draft as **Spec** while **P** still marks the custom chip — **`OverrideExplorerDraftBootstrap`** seeds from **`primaryEnabledOverride`** before **`resyncMockFromServer`** (via **`buildDetail`**).
- **KawarimiHenge**: **Save** with a **numbered** spec chip (e.g. **200 OK**) while the stored row is **off** no longer used the **Spec-only disable** path when the draft matched the OpenAPI template — **`SavePayload.build`** now takes **`pinnedNumberedResponseChip`** so Save sends **`isEnabled: true`** in that case.

### Added

- **KawarimiHenge**: Explorer list **warning** when **two or more** enabled overrides exist for the same OpenAPI operation.

### Changed

- **KawarimiHenge**: **Override explorer** — **`OverrideExplorerDraftBootstrap`** centralizes **open-from-list** draft construction (placeholder → primary overlay → resync); trimmed public doc comments on explorer-related types (behaviour unchanged).
- **Docs**: **henge.md** / **ja/henge.md** — **Explorer state model** (snapshot, draft + stash, mutation bridge), **`isDirty` vs “Not saved”**, **draft bootstrap**, lifecycle (**`henge-ui-data-flow`** kept); **integration.md** / **ja** — link **`#henge-explorer-state`**, lifecycle anchor, **`from: "1.1.0"`** sample pin, **1.1.0** migration note for path helpers.
- **KawarimiHenge**: Single **Save** uses **`SavePayload.build`** — **`mock.isEnabled`** (from chip / stored row) chooses **enabled** (primary; peers disabled first) vs **disabled**; **disabled** saves still send trimmed **body** / **contentType** so JSON persists on the server.
- **KawarimiHenge**: **Primary** indicator is a **`P`** badge on **detail** response chips only (server primary); the sidebar shows status code without **P**. **Spec** chip is accented when it is the effective response (no enabled override).
- **KawarimiHenge**: Sidebar **status / example caption** always reflects **server primary**, not the chip selected for editing; **“Not saved”** and the sidebar **draft dot** use a **server snapshot diff** (persistable mock vs. ``resyncMockFromServer`` canonical), not ``isDirty`` alone, and still consider **stashed** drafts when you switch endpoints.
- **KawarimiHenge**: Switching endpoints **stashes dirty drafts per row** (`pendingDraftsByRowKey`) so returning restores them; spec reload clears stashes.

## [1.0.5] - 2026-04-09

### Fixed

- **KawarimiHenge**: **Spec** vs **200 OK** when **no enabled override** — **chip** selection treats merged template like **Save** (JSON-matched default row → **Spec**) unless the user chose a numbered chip (**`pinnedNumberedResponseChip`** on **`OverrideDetailDraft`**, cleared on resync / save / reset).
- **KawarimiHenge**: **Save** respects **Mock active** — **`isEnabled`** is no longer forced **on** when a matching row exists on the server or for custom responses; the toggle no longer flips after **Save**.
- **KawarimiHenge**: **Save** with **Mock active** off no longer sent **`configure`** for the **first** OpenAPI status only — e.g. disabling **201** incorrectly targeted **200**. **`SavePayload`** now keeps the draft **statusCode** and **exampleId** whenever **Spec-only** early exit does not apply.

### Changed

- **KawarimiConfigView**: enabling a row (**Save** with **Mock active** on) **`configure`**-disables every **other** enabled override for the **same operation** (including **same status**, different **`exampleId`**), before applying the new row — peers keep **`body`** / **`contentType`** (only **`isEnabled: false`**).
- **KawarimiHenge**: **`pinnedNumberedResponseChip`** is cleared when the draft is edited via **`applyMockEdit`** or **Format** (body / mock fields), not only on chip / save / resync.
- **Docs**: **henge.md** / **ja/henge.md** — refresh/sync can replace or skip resync of the open detail (no discard confirmation); exclusive-active peer **`configure`** preserves stored bodies; integration samples pin **`from: "1.0.5"`**.

## [1.0.4] - 2026-04-09

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

[3.3.0]: https://github.com/novr/Kawarimi/releases/tag/v3.3.0
[3.2.0]: https://github.com/novr/Kawarimi/releases/tag/v3.2.0
[3.1.0]: https://github.com/novr/Kawarimi/releases/tag/v3.1.0
[3.0.0]: https://github.com/novr/Kawarimi/releases/tag/v3.0.0
[2.7.0]: https://github.com/novr/Kawarimi/releases/tag/v2.7.0
[2.6.0]: https://github.com/novr/Kawarimi/releases/tag/v2.6.0
[2.5.0]: https://github.com/novr/Kawarimi/releases/tag/v2.5.0
[2.4.0]: https://github.com/novr/Kawarimi/releases/tag/v2.4.0
[2.3.1]: https://github.com/novr/Kawarimi/releases/tag/v2.3.1
[2.3.0]: https://github.com/novr/Kawarimi/releases/tag/v2.3.0
[2.2.2]: https://github.com/novr/Kawarimi/releases/tag/v2.2.2
[2.2.1]: https://github.com/novr/Kawarimi/releases/tag/v2.2.1
[2.2.0]: https://github.com/novr/Kawarimi/releases/tag/v2.2.0
[2.1.0]: https://github.com/novr/Kawarimi/releases/tag/v2.1.0
[2.0.5]: https://github.com/novr/Kawarimi/releases/tag/v2.0.5
[2.0.4]: https://github.com/novr/Kawarimi/releases/tag/v2.0.4
[2.0.3]: https://github.com/novr/Kawarimi/releases/tag/v2.0.3
[2.0.2]: https://github.com/novr/Kawarimi/releases/tag/v2.0.2
[2.0.1]: https://github.com/novr/Kawarimi/releases/tag/v2.0.1
[2.0.0]: https://github.com/novr/Kawarimi/releases/tag/v2.0.0
[1.1.2]: https://github.com/novr/Kawarimi/releases/tag/v1.1.2
[1.1.1]: https://github.com/novr/Kawarimi/releases/tag/v1.1.1
[1.1.0]: https://github.com/novr/Kawarimi/releases/tag/v1.1.0
[1.0.5]: https://github.com/novr/Kawarimi/releases/tag/v1.0.5
[1.0.4]: https://github.com/novr/Kawarimi/releases/tag/v1.0.4
[1.0.3]: https://github.com/novr/Kawarimi/releases/tag/v1.0.3
[1.0.2]: https://github.com/novr/Kawarimi/releases/tag/v1.0.2
[1.0.1]: https://github.com/novr/Kawarimi/releases/tag/v1.0.1
[1.0.0]: https://github.com/novr/Kawarimi/releases/tag/v1.0.0

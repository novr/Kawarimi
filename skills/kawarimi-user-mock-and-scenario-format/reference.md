# Reference — `kawarimi.json` and `kawarimi-scenarios.json`

## Path prefix

Align override `path` and scenario `endpoint.path` with OpenAPI `servers.url` path prefix (e.g. `/api/greet` when server base is `http://host/api`).

Use `KawarimiPath` / `pathPrefix` on `KawarimiConfigStore` consistently with registered routes.

## `kawarimi.json` — `MockOverride` rows

Top-level shape: `{ "overrides": [ … ] }`.

| Field | Required | Notes |
| --- | --- | --- |
| `path` | yes | Operation path including API prefix |
| `method` | yes | HTTP method (e.g. `GET`, `POST`) |
| `statusCode` | yes | Response status for this mock |
| `isEnabled` | yes | Only one enabled row per operation in normal Henge use |
| `rowId` | recommended | UUID; **required** for scenario `cases[].rowId` references |
| `exampleId` | optional | OpenAPI named example key; omit/`null` → `__default` lookup |
| `name` | optional | OpenAPI `operationId`; used for operation identity matching |
| `body` | optional | JSON string; falls back to `KawarimiSpec.responseMap` |
| `contentType` | optional | e.g. `application/json` |
| `delayMs` | optional | 1–60000 ms artificial delay |

### Rules

- **Do not** use `__default` as an OpenAPI `examples` map key (reserved by Kawarimi).
- `configure` / disk load: match by `rowId` first; legacy path+method+status+`exampleId` only when incoming row has no `rowId`.
- Scenario steps resolve overrides **by `rowId` regardless of `isEnabled`**, so preset rows (`isEnabled: false`) can be scenario steps.
- Empty `body` / `contentType` normalize to unset; response may fall back to spec.

### Admin API (runtime)

`POST {pathPrefix}/__kawarimi/configure` upserts a row; returns `200` + override array. See [henge.md](../../docs/henge.md) for Henge API.

## `kawarimi-scenarios.json`

Top-level shape: `{ "scenarios": [ … ] }`.

Default path: same directory as `kawarimi.json`, or `KAWARIMI_SCENARIOS_CONFIG`.

| Field | Notes |
| --- | --- |
| `scenarioId` | Selects scenario (`X-Kawarimi-Scenario-Id`) |
| `initial` | First step when client omits `X-Kawarimi-Id` |
| `cases[]` | Steps in this scenario |

Each **case**:

| Field | Notes |
| --- | --- |
| `kawarimiId` | Step id within scenario |
| `next` | Optional; omit at terminal steps |
| `rowId` | Must match `MockOverride.rowId` in `kawarimi.json` |
| `endpoint.method` | Must match override `method` |
| `endpoint.path` | Must match override `path` (path-only) |

Response bodies come from the **override row**, not from the scenario file.

## HTTP headers (runtime summary)

| Header | Direction | Role |
| --- | --- | --- |
| `X-Kawarimi-Scenario-Id` | Request | Select scenario |
| `X-Kawarimi-Id` | Request | Current step |
| `X-Next-Kawarimi-Id` | Response | Next step when `next` is set |

Full server/client behavior: [henge.md](../../docs/henge.md).

## Decision tree

| Situation | Use |
| --- | --- |
| OpenAPI spec just changed | [#159](https://github.com/novr/Kawarimi/issues/159) — update override rows |
| JSON shape / `rowId` / endpoint alignment | This skill |
| Design a new multi-step flow from requirements | External Scenario Maker, then this skill |

## Mock JSON codegen

How stub bodies are chosen at build time: [mock-json.md](../../docs/mock-json.md).

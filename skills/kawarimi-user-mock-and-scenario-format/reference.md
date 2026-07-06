# Reference — `kawarimi.json` and `kawarimi-scenarios.json`

Scenarios only choose **which override row** serves a step. Bodies live in `kawarimi.json` (or `responseMap`). Wrong links fall back at runtime without a hard error.

## Path prefix

Mismatch with OpenAPI `servers.url` or `pathPrefix` is the most common reason scenario steps never match — the server compares path-only strings.

## `kawarimi.json` — `MockOverride` rows

Top-level shape: `{ "overrides": [ … ] }`.

| Field | Required | Why |
| --- | --- | --- |
| `path` | yes | Must match incoming request path (with prefix) |
| `method` | yes | Same operation as the scenario step |
| `statusCode` | yes | Selects which response variant to mock |
| `isEnabled` | yes | Henge occupation flag; scenario still resolves by `rowId` when disabled |
| `rowId` | recommended | Stable join key for `kawarimi-scenarios.json` cases |
| `exampleId` | optional | Disambiguates named OpenAPI examples; omit → `__default` |
| `name` | optional | `operationId` match can win over path typos |
| `body` | optional | When omitted, runtime uses `KawarimiSpec.responseMap` |
| `contentType` | optional | Required when `body` is set |
| `delayMs` | optional | Artificial latency for tests |

### Rules

- **Do not** use `__default` as an OpenAPI `examples` key — collides with Kawarimi's reserved lookup slot.
- Match by `rowId` first so scenario steps stay stable when path strings are edited.
- Preset rows (`isEnabled: false`) remain valid scenario steps because resolution ignores `isEnabled` for `rowId` lookup.
- Empty `body` / `contentType` normalize away so Henge can mean “use spec default”.

Runtime admin API: [henge.md](../../docs/henge.md).

## `kawarimi-scenarios.json`

Top-level shape: `{ "scenarios": [ … ] }`. Default path: beside `kawarimi.json` (override with `KAWARIMI_SCENARIOS_CONFIG`).

| Field | Why |
| --- | --- |
| `scenarioId` | Selects flow via `X-Kawarimi-Scenario-Id` |
| `initial` | First step when client omits `X-Kawarimi-Id` |
| `cases[]` | Ordered graph of steps |

Each **case**:

| Field | Why |
| --- | --- |
| `kawarimiId` | Step identity within the scenario |
| `next` | Drives `X-Next-Kawarimi-Id`; omit at terminals |
| `rowId` | Join to override body |
| `endpoint.method` / `endpoint.path` | Must match the override row or resolution falls back |

## HTTP headers (runtime summary)

| Header | Direction | Why |
| --- | --- | --- |
| `X-Kawarimi-Scenario-Id` | Request | Picks which flow |
| `X-Kawarimi-Id` | Request | Current step |
| `X-Next-Kawarimi-Id` | Response | Client/server state advance |

Details: [henge.md](../../docs/henge.md).

## Decision tree

| Situation | Why this path |
| --- | --- |
| OpenAPI spec just changed | Overrides must exist before scenarios reference them ([#159](https://github.com/novr/Kawarimi/issues/159)) |
| JSON shape / `rowId` / endpoint alignment | This skill — prevents silent fallback |
| New multi-step flow from requirements | External Maker first, then format here |

Build-time stub rules: [mock-json.md](../../docs/mock-json.md).

# Reference — `kawarimi.json` and `kawarimi-scenarios.json`

Scenarios pick **which override row** serves a step; bodies live in overrides (or `responseMap`). Broken joins fall back at runtime — no hard error.

## Path prefix

If override `path` ≠ request path (including OpenAPI `servers.url` / `pathPrefix`), scenario steps never match.

## `kawarimi.json` — override rows

Shape: `{ "overrides": [ … ] }`.

| Field | Required | Why |
| --- | --- | --- |
| `path` | yes | Mismatch → step never hits this row |
| `method` | yes | Same reason — server matches path + method |
| `statusCode` | yes | Picks response variant when several exist per operation |
| `isEnabled` | yes | Default mock selection; `rowId` lookup ignores this for scenario steps |
| `rowId` | recommended | Without it, scenario cases cannot join stably across edits |
| `exampleId` | optional | Separates named OpenAPI examples on the same operation |
| `name` | optional | `operationId` can match when path strings drift |
| `body` | optional | Omit to use `KawarimiSpec.responseMap` at response time |
| `contentType` | optional | Required when `body` is set |
| `delayMs` | optional | Simulates latency in tests |

### Rules

- Never use `__default` as an OpenAPI `examples` key — reserved by Kawarimi lookup.
- Prefer `rowId` matching so path edits do not break scenario cases.
- `isEnabled: false` rows remain valid scenario steps (`rowId` lookup ignores enabled flag).
- Empty `body` / `contentType` → treat as “use spec default”.

## `kawarimi-scenarios.json`

Shape: `{ "scenarios": [ … ] }`. Default: beside `kawarimi.json` (`KAWARIMI_SCENARIOS_CONFIG` overrides).

| Field | Why |
| --- | --- |
| `scenarioId` | Wrong or duplicate id → wrong flow or ambiguous selection |
| `initial` | Missing matching case → first request has no defined step |
| `cases[]` | Defines the step graph the headers advance through |

Each **case**:

| Field | Why |
| --- | --- |
| `kawarimiId` | Must be unique per scenario; drives `X-Kawarimi-Id` |
| `next` | Omitted at terminals; otherwise client must send returned `X-Next-Kawarimi-Id` |
| `rowId` | Orphan → fallback to non-scenario mock resolution |
| `endpoint.method` / `endpoint.path` | Drift from override row → fallback even when `rowId` exists |

## HTTP headers

| Header | Direction | Why |
| --- | --- | --- |
| `X-Kawarimi-Scenario-Id` | Request | Without it, scenario file is ignored |
| `X-Kawarimi-Id` | Request | Omitted on first request → server uses `initial` |
| `X-Next-Kawarimi-Id` | Response | Client omits on next call → restarts at `initial` |

## When to use what

| Situation | Do this because |
| --- | --- |
| OpenAPI operations changed | Stale overrides make every `rowId` link wrong |
| Validate warnings or new JSON | Silent fallback hides mistakes until integration |
| New flow from product requirements | Maker produces intent; this skill enforces join contracts |

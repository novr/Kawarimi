# KawarimiValidate — limits

Runtime **logs** structural problems and keeps serving. Validator **fails** so broken joins do not reach commit.

**Run:** macOS — `brew install novr/taps/kawarimi-validate`. Linux — `swift run KawarimiValidate`. See [integration.md](../../docs/integration.md).

## Checked (exit `1`)

Server resolves steps by `rowId` + endpoint only — not by loading OpenAPI unless you pass `--spec-snapshot`.

| Check | Severity | Why failure matters |
| --- | --- | --- |
| `scenarioId` | warning | Ambiguous or invalid → wrong or undefined flow |
| `initial` | warning | No matching case → first request undefined |
| `kawarimiId` / `next` | warning | Bad tokens → header state machine breaks |
| Case uniqueness | warning | Duplicate step keys → unpredictable override |
| `rowId` reference | warning (`--spec-snapshot`: **error**) | Orphan → fallback instead of intended body |
| Endpoint match (scenario vs override) | warning | Drift → fallback despite valid-looking `rowId` |

### With `--spec-snapshot` (stderr = error, stdout = warning)

| Check | Severity |
| --- | --- |
| Override `path` + `method` exists in spec endpoints | error |
| Override `statusCode` exists on that endpoint (skipped when override has a non-empty custom `body`, same as runtime) | error |
| Override `exampleId` exists for that status (skipped when override has a non-empty custom `body`, same as runtime) | error |
| Scenario `rowId` exists in overrides | error |
| Scenario case `path` + `method` exists in spec endpoints | warning |

| Edge case | Why handled this way |
| --- | --- |
| Default scenarios path missing (no `--scenarios`, no `KAWARIMI_SCENARIOS_CONFIG`) | Overrides-only edits should still pass |
| `--scenarios` or `KAWARIMI_SCENARIOS_CONFIG` points at missing file | Typo must not masquerade as empty scenarios → exit `2` |
| Config missing / bad JSON | Nothing to cross-check reliably → exit `2` |
| `--spec-snapshot` empty, missing, or invalid JSON | Exit `2` |
| Unused overrides | Allowed — presets need not appear in scenarios |
| Disabled overrides (`isEnabled: false`) | Still cross-checked — stale presets should not drift from the contract |

## Not checked

| Topic | Why omitted |
| --- | --- |
| `body` semantics | Decode errors suffice; meaning needs runtime |
| OpenAPI direct load | Use generated spec / admin wire JSON instead |
| JSON Schema validation | Out of scope for v1 |
| requestBody required | Out of scope for v1 |
| E2E bodies | Needs live server |
| `isEnabled` | Ops choice |
| Graph design (terminals, reachability) | Maker / review |
| Runtime fallback | Validator does not replay traffic |

## Warnings → fix

| Pattern | Cause | Fix |
| --- | --- | --- |
| `rowId … not found` | No override row | Add row or fix `rowId` |
| `endpoint … does not match` | Step ≠ override operation | Align `method`/`path` |
| `Duplicate scenarioId` | Shared id | Rename or merge |
| `initial … has no matching case` | No first step | Add case or fix `initial` |
| `not found in spec` (override) | Stale mock row | Regenerate spec / fix override |
| `exampleId … not found` (override) | Wrong example key | Match spec `responses` / `responseMap` keys |
| `not found in spec` (scenario case) | Step targets non-contract op | Fix scenario endpoint or OpenAPI |

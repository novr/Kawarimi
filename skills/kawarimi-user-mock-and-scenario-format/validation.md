# KawarimiValidate — limits

Runtime **logs** structural problems and keeps serving. Validator **fails** so broken joins do not reach commit.

**Run:** macOS — `brew install novr/taps/kawarimi-validate`. Linux — `swift run KawarimiValidate`. See [integration.md](../../docs/integration.md).

## Checked (exit `1`)

Server resolves steps by `rowId` + endpoint only — not by loading OpenAPI.

| Check | Why failure matters |
| --- | --- |
| `scenarioId` | Ambiguous or invalid → wrong or undefined flow |
| `initial` | No matching case → first request undefined |
| `kawarimiId` / `next` | Bad tokens → header state machine breaks |
| Case uniqueness | Duplicate step keys → unpredictable override |
| `rowId` reference | Orphan → fallback instead of intended body |
| Endpoint match | Drift → fallback despite valid-looking `rowId` |

| Edge case | Why handled this way |
| --- | --- |
| Default scenarios path missing (no `--scenarios`, no `KAWARIMI_SCENARIOS_CONFIG`) | Overrides-only edits should still pass |
| `--scenarios` or `KAWARIMI_SCENARIOS_CONFIG` points at missing file | Typo must not masquerade as empty scenarios → exit `2` |
| Config missing / bad JSON | Nothing to cross-check reliably → exit `2` |
| Unused overrides | Allowed — presets need not appear in scenarios |

## Not checked

| Topic | Why omitted |
| --- | --- |
| `body` semantics | Decode errors suffice; meaning needs runtime |
| Paths vs OpenAPI | Spec not loaded |
| `exampleId` / `responseMap` | Resolved when serving |
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

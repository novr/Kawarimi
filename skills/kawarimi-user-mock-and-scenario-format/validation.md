# KawarimiValidate — scope

`KawarimiValidate` checks **structural consistency** between decoded `kawarimi.json` overrides and `kawarimi-scenarios.json` scenarios.

Implementation: `KawarimiScenarioValidation` in KawarimiCore.

## Guaranteed (exit 1 if any fail)

Cross-check of decoded `overrides[]` and `scenarios[]`:

| Check | Meaning |
| --- | --- |
| `scenarioId` | Normalizable token; no duplicates |
| `initial` | Normalizable; matching `cases[].kawarimiId` exists |
| `kawarimiId` / `next` | Normalizable tokens |
| Case uniqueness | Per scenario: no duplicate `kawarimiId` + `method` + `path` |
| `rowId` reference | Each case `rowId` exists in overrides |
| Endpoint match | Case `method`/`path` matches the referenced override row |

- Missing **scenarios file** → treated as empty `scenarios: []` (exit 0 if overrides OK).
- Missing **config file** or invalid JSON → exit 2 (fatal).

## Not guaranteed

| Topic | Why |
| --- | --- |
| Override `body` is meaningful JSON | Only decode failure is fatal |
| Paths match OpenAPI operations | OpenAPI not loaded |
| `exampleId` / `responseMap` correctness | Runtime resolution |
| E2E response bodies | Needs running server |
| `isEnabled` policy | Henge / ops choice |
| Scenario graph design (terminals, reachability) | Maker / review |
| Runtime fallback when warnings exist | Server still serves via standard override rules |

Warnings at runtime are logged but requests **fall back** (no 503). Fixing warnings keeps scenario steps predictable.

## Warning examples

| Message pattern | Fix |
| --- | --- |
| `rowId … not found in overrides` | Add override with that `rowId` or fix case `rowId` |
| `endpoint … does not match override row` | Align `endpoint.method`/`path` with override `method`/`path` |
| `Duplicate scenarioId` | Rename or merge scenarios |
| `initial … has no matching case` | Add case with that `kawarimiId` or fix `initial` |

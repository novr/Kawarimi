# KawarimiValidate — scope

`KawarimiValidate` exists because runtime only **logs** structural problems and keeps serving requests. CI and agents need a **hard gate** before merge.

Implementation: `KawarimiScenarioValidation` in KawarimiCore.

## Guaranteed (exit 1 if any fail)

These checks matter because the server matches scenario steps by `rowId` and endpoint — not by guessing from OpenAPI at validate time.

| Check | Why it matters |
| --- | --- |
| `scenarioId` | Duplicate or invalid ids make scenario selection ambiguous |
| `initial` | First request must map to a real step |
| `kawarimiId` / `next` | Invalid tokens break header state machines |
| Case uniqueness | Same step key twice → undefined which override wins |
| `rowId` reference | Missing override → step falls back to normal mock resolution |
| Endpoint match | Path/method drift → wrong body or silent fallback |

Edge cases:

- Missing **scenarios file** → treated as `[]` (overrides-only edits stay valid).
- Missing **config** or invalid JSON → exit 2 (nothing reliable to cross-check).
- **Unused overrides** → not reported (presets and Henge-only rows are allowed).

## Not guaranteed

| Topic | Why we skip it |
| --- | --- |
| Override `body` is meaningful JSON | Decode failure is enough; semantics need runtime |
| Paths match OpenAPI operations | Validator does not load the spec |
| `exampleId` / `responseMap` correctness | Resolved at mock response time |
| E2E response bodies | Needs a running server |
| `isEnabled` policy | Operational choice in Henge |
| Scenario graph design | Belongs to Maker / human review |
| Runtime fallback when warnings exist | Documented in henge — validate does not simulate traffic |

## Warning examples

| Message pattern | Why you see it | Fix |
| --- | --- | --- |
| `rowId … not found` | Step points at no override row | Add row or fix `rowId` |
| `endpoint … does not match` | Step would not hit the intended override | Align `method`/`path` with the row |
| `Duplicate scenarioId` | Two flows share one id | Rename or merge |
| `initial … has no matching case` | First step is undefined | Add case or fix `initial` |

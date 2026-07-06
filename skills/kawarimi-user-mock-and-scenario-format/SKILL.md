---
name: kawarimi-user-mock-and-scenario-format
description: >-
  Use when kawarimi.json or kawarimi-scenarios.json must align with Kawarimi runtime
  rowId resolution, or when fixing KawarimiValidate warnings. Not for designing
  multi-step flows from scratch (use an external Scenario Maker first).
---

# Kawarimi mock & scenario format

Requires `openapi.yaml` in context — otherwise override rows cannot match real operations.

## Workflow

1. **Edit** — [reference.md](reference.md). Orphan `rowId` or endpoint mismatch → server falls back silently; wrong body with no error.
2. **Validate** — catch that before commit (runtime only logs warnings).

   **Requires** `Package.swift` to list Kawarimi under `dependencies` (not only `KawarimiCore` on targets). From that package root:

   ```bash
   swift run KawarimiValidate \
     --config path/to/kawarimi.json \
     --scenarios path/to/kawarimi-scenarios.json
   ```

   If `swift run` cannot find the product, run from a Kawarimi clone instead (absolute paths to your JSON):

   ```bash
   cd /path/to/Kawarimi
   swift run KawarimiValidate \
     --config /absolute/path/to/kawarimi.json \
     --scenarios /absolute/path/to/kawarimi-scenarios.json
   ```

   Omit `--scenarios` only when no scenario file exists yet (default path beside config may be missing → exit `0` with overrides only). Pass `--scenarios` or set `KAWARIMI_SCENARIOS_CONFIG` when the file must exist — a typo then exits `2`.

   - `0` — scenario steps will resolve as written
   - `1` — steps may fall back; fix stdout warnings
   - `2` — config unreadable, or explicit scenarios path missing; fix JSON or paths first
3. **Re-run until `0`.**

Patterns: [examples.md](examples.md). Validator limits: [validation.md](validation.md).

## OpenAPI changed?

Fix override `method`/`path`/`statusCode` first — scenario `rowId` links are useless on stale rows.

## Flow design from requirements

Out of scope here. Draft with an external Scenario Maker, then format and validate here.

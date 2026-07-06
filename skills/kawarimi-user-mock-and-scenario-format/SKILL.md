---
name: kawarimi-user-mock-and-scenario-format
description: >-
  Generate or fix kawarimi.json overrides and kawarimi-scenarios.json for Kawarimi
  dynamic mocks. Use when editing mock JSON, fixing KawarimiValidate warnings, or
  aligning scenario rowId with overrides. Not for conversational scenario design
  (use an external Scenario Maker).
---

# Kawarimi mock & scenario format

Agents generate or fix `kawarimi.json` and `kawarimi-scenarios.json`. Users rarely hand-write these files.

**Prerequisites:** project `openapi.yaml` is already in context (from the repo or a Scenario Maker draft). This skill formats and validates JSON; it does not design flows from scratch.

## Workflow

1. **Edit** — apply rules in [reference.md](reference.md); copy patterns from [examples.md](examples.md).
2. **Validate** — from the Kawarimi package root (or a project that depends on Kawarimi):
   ```bash
   swift run KawarimiValidate \
     --config path/to/kawarimi.json \
     --scenarios path/to/kawarimi-scenarios.json
   ```
   - exit `0` — OK
   - exit `1` — structural warnings on stdout; fix and re-run
   - exit `2` — fatal (missing config, invalid JSON)
3. **Re-run until exit 0.**

See [validation.md](validation.md) for what validate does and does not check.

## Runtime behavior

Headers, server middleware, client middleware, reload, and Henge UI: [docs/henge.md](../../docs/henge.md) (runtime only).

## OpenAPI changed?

Use skill/issue **#159** (override row updates). This skill covers JSON shape and `rowId` / endpoint alignment.

## Zero-to-draft scenario design

**Not in Kawarimi.** Delegate to an external Scenario Maker Skill, [#148 MCP](https://github.com/novr/Kawarimi/issues/148), or similar. Then return here to format and validate.

## Related Kawarimi user skills

| Issue | Skill (planned) |
| --- | --- |
| [#158](https://github.com/novr/Kawarimi/issues/158) | First-time Kawarimi integration |
| [#159](https://github.com/novr/Kawarimi/issues/159) | OpenAPI change → override updates |
| **#182** | This skill (format + validate) |

## Install (Cursor)

Copy or symlink this directory into your project:

```text
.cursor/skills/kawarimi-user-mock-and-scenario-format/
```

Or reference files directly from the Kawarimi checkout at `skills/kawarimi-user-mock-and-scenario-format/`.

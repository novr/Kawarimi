---
name: kawarimi-user-mock-and-scenario-format
description: >-
  Generate or fix kawarimi.json overrides and kawarimi-scenarios.json for Kawarimi
  dynamic mocks. Use when editing mock JSON, fixing KawarimiValidate warnings, or
  aligning scenario rowId with overrides. Not for conversational scenario design
  (use an external Scenario Maker).
---

# Kawarimi mock & scenario format

Because users rarely hand-write mock JSON, agents need a single place for **shape rules** and **validation** — not scattered docs that mix runtime behavior with authoring.

**Prerequisites:** `openapi.yaml` is already in context (from the repo or a Scenario Maker draft). This skill finishes and checks JSON; it does not invent flows.

## Workflow

1. **Edit** — follow [reference.md](reference.md) so scenario steps resolve to real override rows at runtime (orphan `rowId` and endpoint mismatch silently fall back on the server).
2. **Validate** — run before commit so structural mistakes fail in CI instead of at integration time:

   ```bash
   swift run KawarimiValidate \
     --config path/to/kawarimi.json \
     --scenarios path/to/kawarimi-scenarios.json
   ```

   - exit `0` — safe to commit
   - exit `1` — fix warnings (scenario steps may not run as intended)
   - exit `2` — invalid or missing config; do not commit
3. **Re-run until exit 0** — runtime logs warnings but still serves traffic; validate catches them early.

Scope and limits: [validation.md](validation.md).

## Runtime behavior

For **why** headers, middleware, and reload behave as they do: [docs/henge.md](../../docs/henge.md) (runtime only — not JSON shape).

## OpenAPI changed?

Use [#159](https://github.com/novr/Kawarimi/issues/159) — overrides must track operations before scenario `rowId` alignment is meaningful.

## Zero-to-draft scenario design

Kawarimi does not design flows. Use an external Scenario Maker, [#148 MCP](https://github.com/novr/Kawarimi/issues/148), or similar, then return here so JSON matches runtime contracts.

## Related Kawarimi user skills

| Issue | When to use |
| --- | --- |
| [#158](https://github.com/novr/Kawarimi/issues/158) | First Kawarimi integration |
| [#159](https://github.com/novr/Kawarimi/issues/159) | OpenAPI change → override rows |
| **#182** | Format + validate (this skill) |

## Install

So agents pick up the same rules in every project without copying markdown by hand:

```bash
# Team / repo — skill travels with the project
npx skills add novr/Kawarimi --skill kawarimi-user-mock-and-scenario-format -y

# Personal default across repos
npx skills add novr/Kawarimi --skill kawarimi-user-mock-and-scenario-format -g -y
```

Discover skills in the repo: `npx skills add novr/Kawarimi --list`.

From a Kawarimi checkout you can also read `skills/kawarimi-user-mock-and-scenario-format/` directly without installing.

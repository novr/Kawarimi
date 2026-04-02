# Mock JSON selection

For each `application/json` response, Kawarimi embeds a JSON string in `KawarimiSpec`.

The generated `Kawarimi` `ClientTransport` mock uses the **200** response body from that process.

## `KawarimiSpec` vs in-process `Kawarimi` transport

These are **two separate code paths** in the generator:

| Output | What it does |
| --- | --- |
| **`KawarimiSpec`** (`endpoints`, `responseMap`) | Emits **every** inline named `examples` entry as its own `MockResponse` row. Example keys are sorted **lexicographically** so generated Swift stays stable across runs. |
| **`Kawarimi` `ClientTransport`** | Emits **one** JSON body per operation for **HTTP 200**, using `defaultResponseJSON`: **`content.example`**, then schema-based mock (`mockJSONBodyFromJSONMediaType`). It does **not** walk the same named-`examples` list as `KawarimiSpec`. |

If the document has **only** an `examples` map (no top-level `example`), OpenAPIKit may still expose a single resolved `example` for the transport path — that value may **not** correspond to a specific row you care about in `KawarimiSpec`. For tests that must hit a **named** example body, prefer an **HTTP** client against a server using `responseMap` / Henge, or accept whichever body the transport generator produced.

The numbered rules below describe the **transport / schema** selection path used for that single 200 body (and overlap with how a **single** spec row is filled when there is no named `examples` map).

The string is chosen in this order:

1. **Media Type Object** — `example`, or the first value resolved from `examples` (OpenAPI 3 disallows both at once; OpenAPIKit fills `example` when only `examples` is set).
2. **JSON Schema on that media type** — `example`, then `default`.
3. **Shape-based synthesis** — recurse through `object` / `array` properties (placeholder values for primitives when needed).
4. **`oneOf` / `anyOf`** — first branch whose result is not an empty placeholder (`{}`, `""`, `0`, `false`, `[]`); if every branch is placeholder-like, the first branch is used.
5. **`allOf`** — first subschema (heuristic when no explicit example).
6. **`enum` (`allowedValues`)** — first value, encoded as JSON.
7. **Primitives** — string `""`, number `0`, etc.; unknown shapes fall back to `{}`.

`KawarimiHandler` stub generation is separate.

Some schemas (e.g. certain enums) still require manual `on…` handlers or `handlerStubPolicy` even when the mock JSON above is available.

## Named examples and `responseMap`

When a response’s `application/json` block defines an OpenAPI **`examples` map** with **inline** values, Kawarimi emits **one `MockResponse` per map entry**.

Entries are ordered by **example key** (Unicode code point order) so output is deterministic.

Each entry’s key is the `exampleId`, and `KawarimiSpec.responseMap` nests bodies as **`[statusCode: [exampleId: (body, contentType)]]`**.

**Reserved:** do not use **`__default`** as an OpenAPI `examples` map key — Kawarimi reserves that string for the synthetic default row and for lookup when overrides omit `exampleId`. See **Reserved: `__default`** in [henge.md](henge.md).

Map entries that only have **`externalValue`** (no inline JSON) are **skipped** during generation.

The generator may fall back to a single synthesized body under **`__default`** using the rules above.

A **single** inline `example` or a single resolved value behaves as one row with **`exampleId` `__default`** in the generated spec (unless multiple named examples exist).

See [henge.md](henge.md) for:

- Runtime overrides and `kawarimi.json`.
- How Henge and interceptors use **`__default`** when `MockOverride.exampleId` is omitted.

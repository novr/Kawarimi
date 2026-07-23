# Mock JSON selection

For each `application/json` response, Kawarimi embeds a JSON string in `KawarimiSpec`.

The generated `Kawarimi` `ClientTransport` mock uses the **200** response body from that process.

## KawarimiSpec: 204 and non-JSON responses

`KawarimiSpec` uses different rules when a response is not `application/json`:

| Case | `contentType` | `body` |
| --- | --- | --- |
| HTTP **204** or a response with **no** `content` | `""` (empty) | `""` |
| Non-JSON media type (e.g. `application/xml`) | The OpenAPI media type (first non-JSON `content` entry, lexicographic) | Inline `example` string when present; otherwise `""` |

`KawarimiServerMiddleware` omits the `Content-Type` header when the resolved mock row has an empty `contentType`, and returns no response body when both `contentType` and `body` are empty.

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
5. **`allOf`** — **not** full [JSON Schema `allOf`](https://json-schema.org/understanding-json-schema/reference/combining#allof) semantics (all subschemas satisfied on one instance). Kawarimi does a **shallow merge of object-shaped JSON only**:
   - For each subschema, the same synthesis rules run; if the result parses as a **JSON object** (`{ ... }`), its **top-level keys** are merged into one object. **Later** subschemas in the `allOf` array **override** the same key from an earlier one.
   - Subschemas whose synthesized JSON is **not** a top-level object (primitives, arrays, or branches that fail to parse as an object) **do not contribute keys** and are effectively **ignored** for merging.
   - If no keys were merged (for example only non-object branches), Kawarimi **falls back** to the **first** subschema’s synthesized JSON (same as older behavior).
6. **`enum` (`allowedValues`)** — first value, encoded as JSON.
7. **Primitives** — string `""`, number `0`, etc.; unknown shapes fall back to `{}`.

### Date (`format: date-time` / `date`)

| Path | Wire JSON | Swift stub |
| --- | --- | --- |
| **Mock JSON** (`KawarimiSpec`, transport, decode stub string) | JSON **string** (schema `example` when present and parseable; otherwise **`1970-01-01T00:00:00Z`** or **`1970-01-01`** for `date` only — never `""`) | — |
| **Handler literal** (initializer path) | — | `Date(timeIntervalSince1970:…)` from parsed `example` at codegen |
| **Handler decode** (`allOf` / enum / etc.) | Same synthesized JSON string as mock JSON | `Self._kawarimiStubJSONDecoder()` (`.iso8601` + date-only / pattern fallback) |

For **mock JSON**, `format: date-time` / `date` is resolved **before** generic schema `example` encoding so unparseable date examples do not leak into the wire JSON. When the mock JSON path falls back (missing example, or example string that does not parse), Kawarimi emits the same **`Kawarimi warning: … epoch 0 …`** line to **stderr** as the handler literal path (with `operationId` and OpenAPI path context).

## KawarimiHandler default stubs

`KawarimiHandler` reuses the **same JSON synthesis** as the transport mock when a **literal Swift initializer** for the `application/json` body cannot be generated (for example string `enum` / `allowedValues`, or `allOf` / `oneOf` / `anyOf` shapes the initializer path rejects).
In that case the emitted stub decodes the synthesized string with **`Self._kawarimiStubJSONDecoder()`** (ISO8601-compatible string dates, including `format: date`) into the type **swift-openapi-generator** produced: `Components.Schemas.*` when the response schema is a **`$ref`**, otherwise `Operations.<Operation>.Output.(Ok|Created).Body.jsonPayload`.

When a **literal initializer can be emitted**, that path is preferred (no decode at runtime).

For **`type: string`** with **`format: date-time`** or **`format: date`**, that literal path emits **`Date(timeIntervalSince1970:…)`** (parsed from the schema **`example`** at codegen time) so it matches **`Foundation.Date`** fields from **swift-openapi-generator**.

If the documented success response is **not** a stubbable **HTTP 200 / 201** (`application/json` or empty body) or **204**, generation fails with `handlerStubPolicy: throw`, or the stub body is `fatalError` with `handlerStubPolicy: fatalError` (see [integration.md](integration.md)).
Use a custom `on…` closure when you need different behavior or when the decode type does not match your document (rare naming edge cases).

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
- `exampleId` meaning only (not row identity; persisted row identity uses optional `rowId` first).

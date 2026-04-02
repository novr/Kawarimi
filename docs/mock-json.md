# Mock JSON selection

For each `application/json` response, Kawarimi embeds a JSON string in `KawarimiSpec`.

The generated `Kawarimi` `ClientTransport` mock uses the **200** response body from that process.

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

Each entry’s key is the `exampleId`, and `KawarimiSpec.responseMap` nests bodies as **`[statusCode: [exampleId: (body, contentType)]]`**.

Map entries that only have **`externalValue`** (no inline JSON) are **skipped** during generation.

The generator may fall back to a single synthesized body under **`__default`** using the rules above.

A **single** inline `example` or a single resolved value behaves as one row with **`exampleId` `__default`** in the generated spec (unless multiple named examples exist).

See [henge.md](henge.md) for:

- Runtime overrides and `kawarimi.json`.
- How Henge and interceptors use **`__default`** when `MockOverride.exampleId` is omitted.

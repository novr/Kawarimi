# Mock JSON selection

For each `application/json` response, Kawarimi embeds a JSON string in `KawarimiSpec` (and uses the **200** response for the generated `Kawarimi` `ClientTransport` mock). The string is chosen in this order:

1. **Media Type Object** — `example`, or the first value resolved from `examples` (OpenAPI 3 disallows both at once; OpenAPIKit fills `example` when only `examples` is set).
2. **JSON Schema on that media type** — `example`, then `default`.
3. **Shape-based synthesis** — recurse through `object` / `array` properties (placeholder values for primitives when needed).
4. **`oneOf` / `anyOf`** — first branch whose result is not an empty placeholder (`{}`, `""`, `0`, `false`, `[]`); if every branch is placeholder-like, the first branch is used.
5. **`allOf`** — first subschema (heuristic when no explicit example).
6. **`enum` (`allowedValues`)** — first value, encoded as JSON.
7. **Primitives** — string `""`, number `0`, etc.; unknown shapes fall back to `{}`.

`KawarimiHandler` stub generation is separate: some schemas (e.g. certain enums) still require manual `on…` handlers or `handlerStubPolicy` even when the mock JSON above is available.

See also [henge.md](henge.md) for runtime overrides and `kawarimi.json`.

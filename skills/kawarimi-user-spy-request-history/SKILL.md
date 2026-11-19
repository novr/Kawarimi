---
name: kawarimi-user-spy-request-history
description: >-
  Use when an E2E or QA runner must check which HTTP requests the client sent,
  via GET and DELETE {pathPrefix}/__kawarimi/requests. Not for implementing the
  recorder, and not for a specific runner's scripts or environment.
---

# Kawarimi Spy request history

Caller contract for the Spy admin routes. `{pathPrefix}` is the prefix the host mounts admin on (DemoServer uses `/api`). Pin this directory at a release tag; do not copy it from `main`.

## List

`GET {pathPrefix}/__kawarimi/requests` → **200**, `Content-Type: application/json`, and a JSON array in **record / completion order** (not receive-time order).

Filters are optional and AND-ed. A repeated key uses the last value. Unknown keys are ignored.

| Query | Match |
| --- | --- |
| `operationId` | Exact `matchedOperationId`. Aggregates one operation across different path ids. |
| `path` | Exact path as the server received it. Not an OpenAPI template, and not percent-decoded. |
| `method` | Case-insensitive. |

Percent-encode filter values. A space is `%20`. A literal `+` is `%2B` (it is not a space). Prefer `-G --data-urlencode` so `/`, `&`, `=`, `%`, and `+` in values stay intact.

```bash
curl -s 'http://127.0.0.1:8080/api/__kawarimi/requests'
curl -sG 'http://127.0.0.1:8080/api/__kawarimi/requests' \
  --data-urlencode 'operationId=getGreeting' \
  --data-urlencode 'path=/api/greet' \
  --data-urlencode 'method=GET'
```

## Clear

`DELETE {pathPrefix}/__kawarimi/requests` → **200**, `Content-Type: application/json`, and `{}`.

```bash
curl -s -X DELETE 'http://127.0.0.1:8080/api/__kawarimi/requests'
```

## One recorded object

| Field | Meaning |
| --- | --- |
| `id` | Id assigned when recorded. |
| `timestamp` | Receive time, ISO-8601 with fractional seconds. |
| `method` | HTTP method. |
| `path` | Path as received. Not percent-decoded. |
| `queryItems` | Array of objects with `name` and `value`, order kept. `value` may be JSON `null`. Percent-decoded. A broken escape such as `%zz` stays as written. `+` stays `+`. |
| `headers` | Lowercase names. Duplicate names keep the last value. |
| `body` | UTF-8 text, or `null`. |
| `matchedOperationId` | Operation id, or `null`. |
| `action` | `mock` (override or scenario), `forward` (configured upstream), or `passthrough` (downstream handler). |
| `responseStatusCode` | Status sent back, or `null` for a `hang` / `connectionClose` mock or a downstream throw. |

`body`, `matchedOperationId`, `responseStatusCode`, and query `value` are always present. Unknown is `null`, not a missing key.

`authorization`, `proxy-authorization`, `cookie`, and `set-cookie` are stored as `[redacted]`. The key stays, so you can see that the header was sent.

## What is not in the list

- `/__kawarimi/*` admin calls.
- Paths that are not a registered OpenAPI operation (the usual 404).

History is in memory. The default cap is 500 entries (the host can set another cap); the oldest entry is dropped. `body` keeps about 1 MiB of UTF-8, cut on a character boundary. Invalid UTF-8 is `null`. For **`mock`**, the recorder itself reads up to that cap. For **`forward`** / **`passthrough`**, only bytes the downstream actually reads are captured; unread bodies stay `null` or partial.

Array order is completion order. `timestamp` is receive time, so a delayed mock can finish after a later request. Sort by `timestamp` when order matters.

`200` with `[]` means Spy is enabled and nothing is recorded. `404` means this host did not enable Spy.

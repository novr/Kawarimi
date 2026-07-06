# Examples — patterns

Adapt every `path`, `method`, `name`, `exampleId`, body, and `rowId` from the project's `openapi.yaml`. Copying literals from below without adaptation will break joins.

## Two-step flow (same operation, two bodies)

Use when one operation must return different bodies across consecutive calls (enabled row = default mock; disabled preset = later step).

**`kawarimi.json`** (excerpt):

```json
{
  "overrides": [
    {
      "body": "{\"message\":\"Hello\"}",
      "contentType": "application/json",
      "exampleId": "step_a",
      "isEnabled": true,
      "method": "GET",
      "name": "yourOperationId",
      "path": "/api/your-path",
      "rowId": "00000000-0000-0000-0000-000000000001",
      "statusCode": 200
    },
    {
      "body": "{\"message\":\"Hello again\"}",
      "contentType": "application/json",
      "exampleId": "step_b",
      "isEnabled": false,
      "method": "GET",
      "name": "yourOperationId",
      "path": "/api/your-path",
      "rowId": "00000000-0000-0000-0000-000000000002",
      "statusCode": 200
    }
  ]
}
```

**`kawarimi-scenarios.json`**:

```json
{
  "scenarios": [
    {
      "scenarioId": "your_flow",
      "initial": "step_a",
      "cases": [
        {
          "kawarimiId": "step_a",
          "next": "step_b",
          "rowId": "00000000-0000-0000-0000-000000000001",
          "endpoint": { "method": "GET", "path": "/api/your-path" }
        },
        {
          "kawarimiId": "step_b",
          "rowId": "00000000-0000-0000-0000-000000000002",
          "endpoint": { "method": "GET", "path": "/api/your-path" }
        }
      ]
    }
  ]
}
```

`next` on `step_a` requires the client to send `X-Next-Kawarimi-Id: step_b` on the follow-up — otherwise the server restarts at `initial`.

## One-step error (terminal)

Use when a single call must return an error body and later calls without `X-Kawarimi-Id` should hit `initial` again.

**Override row**:

```json
{
  "body": "{\"code\":\"VALIDATION_ERROR\",\"message\":\"Invalid input\"}",
  "contentType": "application/json",
  "exampleId": "validation_error",
  "isEnabled": false,
  "method": "POST",
  "name": "yourOperationId",
  "path": "/api/your-path",
  "rowId": "00000000-0000-0000-0000-000000000003",
  "statusCode": 400
}
```

**Scenario**:

```json
{
  "scenarioId": "your_validation_flow",
  "initial": "error",
  "cases": [
    {
      "kawarimiId": "error",
      "rowId": "00000000-0000-0000-0000-000000000003",
      "endpoint": { "method": "POST", "path": "/api/your-path" }
    }
  ]
}
```

## Validate

```bash
swift run KawarimiValidate \
  --config path/to/kawarimi.json \
  --scenarios path/to/kawarimi-scenarios.json
```

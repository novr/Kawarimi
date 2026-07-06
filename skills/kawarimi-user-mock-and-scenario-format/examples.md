# Examples — override + scenario pairs

Copy these when agents need **working joins** between `rowId` and endpoints — not when designing new flows (use a Maker first).

Golden fixtures: [Example/DemoPackage](../../Example/DemoPackage/).

## Greet — two-step (`GET /api/greet`)

**`kawarimi.json`** (excerpt — two preset rows, one enabled):

```json
{
  "overrides": [
    {
      "body": "{\"message\":\"Hello from API\"}",
      "contentType": "application/json",
      "exampleId": "success",
      "isEnabled": true,
      "method": "GET",
      "name": "getGreeting",
      "path": "/api/greet",
      "rowId": "00000000-0000-0000-0000-000000000001",
      "statusCode": 200
    },
    {
      "body": "{\"message\":\"Good day from API\"}",
      "contentType": "application/json",
      "exampleId": "formal",
      "isEnabled": false,
      "method": "GET",
      "name": "getGreeting",
      "path": "/api/greet",
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
      "scenarioId": "greet",
      "initial": "success",
      "cases": [
        {
          "kawarimiId": "success",
          "next": "formal",
          "rowId": "00000000-0000-0000-0000-000000000001",
          "endpoint": { "method": "GET", "path": "/api/greet" }
        },
        {
          "kawarimiId": "formal",
          "rowId": "00000000-0000-0000-0000-000000000002",
          "endpoint": { "method": "GET", "path": "/api/greet" }
        }
      ]
    }
  ]
}
```

Flow: first request uses `initial` → `success` row; response includes `X-Next-Kawarimi-Id: formal`; second request uses `formal` row (terminal, no `next`).

## Create item — one-step error (`POST /api/items` → 400)

Terminal error step (no `next`). Next request without `X-Kawarimi-Id` restarts at `initial`.

**Override row** (add to `kawarimi.json`):

```json
{
  "body": "{\"code\":\"VALIDATION_ERROR\",\"message\":\"Invalid item\"}",
  "contentType": "application/json",
  "exampleId": "validation_error",
  "isEnabled": false,
  "method": "POST",
  "name": "createItem",
  "path": "/api/items",
  "rowId": "00000000-0000-0000-0000-000000000003",
  "statusCode": 400
}
```

**Scenario** (add to `kawarimi-scenarios.json`):

```json
{
  "scenarioId": "createItem_validation",
  "initial": "error",
  "cases": [
    {
      "kawarimiId": "error",
      "rowId": "00000000-0000-0000-0000-000000000003",
      "endpoint": { "method": "POST", "path": "/api/items" }
    }
  ]
}
```

## Validate

```bash
swift run KawarimiValidate \
  --config Example/DemoPackage/kawarimi.json.example \
  --scenarios Example/DemoPackage/kawarimi-scenarios.json
```

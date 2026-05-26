# Detail column — layout regression

Guards against regressions in the override **detail column** (header, JSON editor, bottom toolbar).

| Failure | Pass when |
|---------|-----------|
| Bottom toolbar missing | Validate / Format / Save / Reset stay visible with the editor |
| Header crushed or hidden | Operation ID, tags, and status chips remain readable |
| Long JSON hides chrome | Toolbar stays fixed; only the JSON area scrolls |

Numeric layout: `DetailColumnLayoutCoreTests` (#118). **Preview** covers stateless layout only; **manual** checks below cover the rest.

## Preview (DemoApp, stateless)

Open `Example/DemoApp/DemoAppUI/DetailColumnPreviews.swift` (DemoApp scheme).

| | Pass when |
|---|-----------|
| Sparse metadata | Header + toolbar visible together (`getGreeting`-like) |
| Security heavy | Long SECURITY scrolls in the header area; toolbar still visible |
| Long JSON | Toolbar visible; JSON scrolls inside the editor |

Not in Preview: mock off, dirty/save errors, chip apply, sheets — exercise in Henge manually.

## Manual (DemoServer + Henge)

| | Pass when |
|---|-----------|
| `getGreeting` | Same as sparse row above on a live server |
| `listItems` | Toolbar fixed while the header scrolls |
| Long JSON on any op | Toolbar fixed; editor body scrolls |

## See also

- [#119](https://github.com/novr/Kawarimi/issues/119)
- [#118](https://github.com/novr/Kawarimi/pull/118)

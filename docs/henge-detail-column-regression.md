# Henge detail column — UI regression

Minimal visual regression for the override **detail column** (header, JSON editor, bottom toolbar). Numeric layout contracts live in `DetailColumnLayoutCoreTests` (#118).

## `#Preview` patterns (DemoApp)

Build with **DemoApp** scheme (`Example/DemoApp.xcodeproj`). Previews are defined in `Example/DemoApp/DemoAppUI/DetailColumnPreviews.swift`; fixtures and `*PreviewRoot` views live in **KawarimiHenge** (`DEBUG` only).

| ID | `#Preview` name | What to verify |
|----|-----------------|----------------|
| P1 | `Detail column — sparse metadata` | Header (operationId, tags) and bottom toolbar visible together |
| P2 | `Detail column — security heavy` | Long security header scrolls inside top `ScrollView`; toolbar stays pinned at bottom |
| P3 | `Detail column — long JSON` | Toolbar visible; JSON scrolls inside the editor chrome |
| P4 | `Detail column header — sparse` | Header-only smoke test |
| P5 | `Detail column toolbar — tight` | Tight toolbar height (76pt) |

### RenderPreview (PR evidence)

1. Open `Example/DemoApp.xcodeproj` in Xcode; select scheme **DemoApp**.
2. Enable Xcode MCP (`xcrun mcpbridge`; Coding Intelligence in Xcode settings).
3. Call **RenderPreview** (Xcode MCP) with:
   - `tabIdentifier`: active workspace tab (from the tool error hint if missing)
   - `sourceFilePath`: `DemoApp/DemoAppUI/DetailColumnPreviews.swift` (path within the Xcode project)
   - `previewDefinitionIndexInFile`: `0` = P1 … `4` = P5 (order in the Swift file)
4. Copy `previewSnapshotPath` from the tool JSON into `docs/assets/henge/detail-column/` and reference in the PR.

RenderPreview is **not** run in CI.

## Manual checks (HengeCli or DemoApp Henge tab)

Start **DemoServer** (or your admin API), then open Henge against the Demo API base URL.

| Case | Demo `operationId` | Steps | Pass |
|------|-------------------|-------|------|
| Sparse metadata | `getGreeting` | Select GET `/greet` | Header and toolbar always visible |
| Security-heavy | `listItems` (or any op with security docs) | Select operation; scroll header | Toolbar stays visible while header scrolls |
| Long JSON | Any op | Enable mock; paste or grow JSON to many lines | Toolbar visible; only editor body scrolls |

## Related

- [#119](https://github.com/novr/Kawarimi/issues/119) — tracking issue
- [#118](https://github.com/novr/Kawarimi/pull/118) — layout core + view split

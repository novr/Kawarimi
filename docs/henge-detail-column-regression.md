# Henge detail column — UI regression

Minimal **stateless** visual checks for the override detail column (header, JSON editor, bottom toolbar). Numeric layout contracts live in `DetailColumnLayoutCoreTests` (#118).

**Out of scope for `#Preview`:** stateful flows (mock disabled, unsaved drafts, chip apply, save/configure errors, navigation sheets). Use manual HengeCli / DemoApp checks below.

## `#Preview` patterns (DemoApp)

Build with **DemoApp** scheme (`Example/DemoApp.xcodeproj`).

| Location | Role |
|----------|------|
| `Example/DemoApp/DemoAppUI/DetailColumnPreviewFixtures.swift` | Fake endpoints + mocks (`KawarimiCore` only) |
| `Example/DemoApp/DemoAppUI/DetailColumnPreviews.swift` | `#Preview` macros |
| `KawarimiHenge` `DetailColumnPreviewCanvas` (`DEBUG`) | Composes internal column views; no fixtures |

| ID | `#Preview` name | What to verify |
|----|-----------------|----------------|
| P1 | `Detail column — sparse metadata` | Header (operationId, tags) and bottom toolbar visible together |
| P2 | `Detail column — security heavy` | Long SECURITY block scrolls in top `ScrollView`; toolbar pinned (synthetic fixture; hand-check `listItems` separately) |
| P3 | `Detail column — long JSON` | Toolbar visible; JSON scrolls inside editor chrome |
| P4 | `Detail column header — sparse` | Header-only smoke |
| P5 | `Detail column toolbar — tight` | Tight toolbar height (76pt) |

### RenderPreview (optional, not stored in repo)

For PR discussion only — **do not commit** PNGs under `docs/`.

1. Open `Example/Example.xcworkspace`, scheme **DemoApp**.
2. Enable Xcode MCP (`xcrun mcpbridge`).
3. `RenderPreview`: `sourceFilePath` = `DemoApp/DemoAppUI/DetailColumnPreviews.swift`, `previewDefinitionIndexInFile` = `0`…`4`, `tabIdentifier` from the tool hint.
4. Attach screenshots to the PR comment or description locally; they are not part of the tree.

**CI:** DemoApp / `#Preview` build is tracked separately (not in this doc).

## Manual checks (HengeCli or DemoApp Henge tab)

Start **DemoServer**, open Henge on the Demo admin URL.

| Case | Demo `operationId` | Pass |
|------|-------------------|------|
| Sparse metadata | `getGreeting` | Header and toolbar always visible |
| Security-heavy | `listItems` | Toolbar visible while header scrolls |
| Long JSON | Any op | Toolbar visible; editor body scrolls |
| Stateful (optional) | Any | Disabled mock / save error / chip change behaves as expected |

## Related

- [#119](https://github.com/novr/Kawarimi/issues/119)
- [#118](https://github.com/novr/Kawarimi/pull/118)

/// Override editor — where logic lives (documentation anchor only).
///
/// Business rules for the mock override **editor** (``ResponseChips``, Save ``SavePayload``, ``DisableMockPlanner``,
/// ``EndpointFilter``, ``HTTPStatusPhrase``, ``EditorValidation``, ``NavigationLayoutLogic``, ``MockDraftDefaults``)
/// live in this directory and small related types (e.g. ``ExplorerPalette``). **Do not** duplicate those condition
/// chains inside ``OverrideEditorStore``.
///
/// ``OverrideEditorStore`` / ``OverrideDetailDraft`` own selection, draft lifecycle, list status synthesis,
/// JSON validate/format, and resync orchestration. Shared matching lives in ``OverrideListQueries`` and
/// **KawarimiCore** (`MockOverride`, `OpenAPIPathPrefix`, …).
enum EditorModuleDoc: Sendable {}

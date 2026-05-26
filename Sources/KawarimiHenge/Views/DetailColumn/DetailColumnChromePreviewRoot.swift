#if DEBUG
import KawarimiCore
import KawarimiHengeCore
import SwiftUI

/// P1 — sparse metadata chrome (`#Preview` in DemoApp).
public struct DetailColumnSparseChromePreviewRoot: View {
    public init() {}

    public var body: some View {
        DetailColumnChromePreviewShell(data: DetailColumnPreviewFixtures.sparseChromeData)
    }
}

/// P2 — security-heavy header chrome (`#Preview` in DemoApp).
public struct DetailColumnSecurityHeavyChromePreviewRoot: View {
    public init() {}

    public var body: some View {
        DetailColumnChromePreviewShell(data: DetailColumnPreviewFixtures.securityHeavyChromeData)
    }
}

/// P3 — long JSON body chrome (`#Preview` in DemoApp).
public struct DetailColumnLongJSONChromePreviewRoot: View {
    public init() {}

    public var body: some View {
        DetailColumnChromePreviewShell(data: DetailColumnPreviewFixtures.longJSONChromeData)
    }
}

private struct DetailColumnChromePreviewShell: View {
    let data: DetailColumnChromePreviewData

    var body: some View {
        DetailColumnChromePreviewContent(data: data)
            .frame(width: 420, height: 720)
    }
}

private struct DetailColumnChromePreviewContent: View {
    let data: DetailColumnChromePreviewData

    @State private var mock: MockOverride
    @State private var bodyText: String
    @State private var contentTypeText: String
    @State private var delayMsText = ""
    @State private var confirmResetEndpoint = false
    @FocusState private var detailFocus: DetailColumnFocusField?

    init(data: DetailColumnChromePreviewData) {
        self.data = data
        _mock = State(initialValue: data.initialMock)
        _bodyText = State(initialValue: data.initialMock.body ?? "{}")
        _contentTypeText = State(initialValue: data.initialMock.contentType ?? "application/json")
    }

    var body: some View {
        DetailColumnScrollStack(
            showResponseBody: true,
            header: {
                DetailColumnHeaderView(
                    model: DetailColumnHeaderModel(
                        endpointItem: data.endpointItem,
                        securityPresentation: data.securityPresentation,
                        chipOptions: data.chipOptions,
                        primaryOverride: nil,
                        pinnedNumberedResponseChip: false,
                        hasUnsavedChanges: false,
                        tightVertical: false,
                        showResponseBodyHeading: true,
                        selectedResponseDocumentation: nil,
                        canRemoveCurrentMockRow: false
                    ),
                    actions: DetailColumnHeaderActions(
                        onApplyChip: { _ in },
                        onDisableCurrentMock: {},
                        onPresentAddCustom: {}
                    ),
                    bindings: DetailColumnHeaderBindings(
                        mock: $mock,
                        contentTypeText: $contentTypeText,
                        delayMsText: $delayMsText,
                        focus: $detailFocus
                    )
                )
            },
            editor: {
                DetailColumnJsonEditorView(
                    bodyText: $bodyText,
                    validationMessage: nil,
                    tightVertical: false,
                    focus: $detailFocus
                )
            },
            toolbar: {
                DetailColumnBottomToolbarView(
                    tightVertical: false,
                    onValidate: {},
                    onFormat: {},
                    onSave: {},
                    confirmResetEndpoint: $confirmResetEndpoint
                )
            }
        )
    }
}
#endif

#if DEBUG
import KawarimiCore
import KawarimiHengeCore
import SwiftUI

/// Example / Canvas: detail-column chrome (header + editor + toolbar) for P1–P3.
public struct DetailColumnChromePreviewRoot: View {
    private let scenario: DetailColumnPreviewScenario

    public init(_ scenario: DetailColumnPreviewScenario) {
        self.scenario = scenario
    }

    public var body: some View {
        DetailColumnChromePreviewContent(scenario: scenario)
            .frame(width: 420, height: 720)
    }
}

private struct DetailColumnChromePreviewContent: View {
    let scenario: DetailColumnPreviewScenario

    @State private var mock: MockOverride
    @State private var bodyText: String
    @State private var contentTypeText: String
    @State private var delayMsText = ""
    @State private var confirmResetEndpoint = false
    @FocusState private var detailFocus: DetailColumnFocusField?

    init(scenario: DetailColumnPreviewScenario) {
        self.scenario = scenario
        let initialMock = DetailColumnPreviewFixtures.mock(for: scenario)
        _mock = State(initialValue: initialMock)
        _bodyText = State(initialValue: initialMock.body ?? "{}")
        _contentTypeText = State(initialValue: initialMock.contentType ?? "application/json")
    }

    var body: some View {
        DetailColumnScrollStack(
            showResponseBody: true,
            header: {
                DetailColumnHeaderView(
                    model: DetailColumnHeaderModel(
                        endpointItem: DetailColumnPreviewFixtures.endpointItem(for: scenario),
                        securityPresentation: DetailColumnPreviewFixtures.securityPresentation(for: scenario),
                        chipOptions: DetailColumnPreviewFixtures.chipOptions(for: scenario),
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

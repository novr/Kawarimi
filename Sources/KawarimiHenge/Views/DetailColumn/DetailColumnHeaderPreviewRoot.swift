#if DEBUG
import KawarimiCore
import KawarimiHengeCore
import SwiftUI

/// Example / Canvas: sparse detail-column header (`#Preview` lives in DemoApp).
public struct DetailColumnHeaderPreviewRoot: View {
    public init() {}

    public var body: some View {
        DetailColumnHeaderPreviewContent()
            .frame(width: 420)
    }
}

private struct DetailColumnHeaderPreviewContent: View {
    @State private var mock = DetailColumnPreviewFixtures.sparseHeaderMock
    @State private var contentTypeText = "application/json"
    @State private var delayMsText = ""
    @FocusState private var focus: DetailColumnFocusField?

    var body: some View {
        DetailColumnHeaderView(
            model: DetailColumnHeaderModel(
                endpointItem: DetailColumnPreviewFixtures.sparseHeaderEndpointItem,
                securityPresentation: DetailColumnPreviewFixtures.sparseHeaderSecurityPresentation,
                chipOptions: DetailColumnPreviewFixtures.sparseHeaderChipOptions,
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
                focus: $focus
            )
        )
    }
}
#endif

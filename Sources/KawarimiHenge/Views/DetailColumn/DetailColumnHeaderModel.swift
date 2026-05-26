import KawarimiCore
import KawarimiHengeCore
import SwiftUI

struct DetailColumnHeaderModel {
    let endpointItem: SpecEndpointItem
    let securityPresentation: EndpointSecurityPresentation
    let chipOptions: [ResponseChip]
    let primaryOverride: MockOverride?
    let pinnedNumberedResponseChip: Bool
    let hasUnsavedChanges: Bool
    let tightVertical: Bool
    let showResponseBodyHeading: Bool
    let selectedResponseDocumentation: ResponseDocumentation?
    let canRemoveCurrentMockRow: Bool
}

struct DetailColumnHeaderActions {
    let onApplyChip: (ResponseChip) -> Void
    let onDisableCurrentMock: () -> Void
    let onPresentAddCustom: () -> Void
}

struct DetailColumnHeaderBindings {
    var mock: Binding<MockOverride>
    var contentTypeText: Binding<String>
    var delayMsText: Binding<String>
    var focus: FocusState<DetailColumnFocusField?>.Binding
}

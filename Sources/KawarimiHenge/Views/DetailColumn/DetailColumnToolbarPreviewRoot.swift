#if DEBUG
import SwiftUI

/// Example / Canvas: bottom toolbar at tight vertical metrics (P5).
public struct DetailColumnToolbarPreviewRoot: View {
    public init() {}

    @State private var confirmResetEndpoint = false

    public var body: some View {
        DetailColumnBottomToolbarView(
            tightVertical: true,
            onValidate: {},
            onFormat: {},
            onSave: {},
            confirmResetEndpoint: $confirmResetEndpoint
        )
        .frame(width: 420)
    }
}
#endif

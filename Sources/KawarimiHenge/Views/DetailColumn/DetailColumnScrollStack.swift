import SwiftUI

struct DetailColumnScrollStack<Header: View, Toolbar: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let toolbar: () -> Toolbar

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                header()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ExplorerPalette.surface)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            toolbar()
        }
    }
}

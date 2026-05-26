import SwiftUI
import KawarimiHengeCore

struct DetailColumnBottomToolbarView: View {
    let tightVertical: Bool
    let onValidate: () -> Void
    let onFormat: () -> Void
    let onSave: () -> Void
    @Binding var confirmResetEndpoint: Bool

    var body: some View {
        HStack(spacing: 4) {
            toolbarPlainButton(title: "Validate", systemImage: "checkmark.circle", action: onValidate)
            toolbarPlainButton(title: "Format", systemImage: "text.alignleft", action: onFormat)
            saveCapsuleButton
            toolbarPlainButton(title: "Reset", systemImage: "arrow.counterclockwise", foreground: .red) {
                confirmResetEndpoint = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, tightVertical ? 8 : 12)
        .padding(.horizontal, 8)
        .frame(height: CGFloat(DetailColumnLayoutCore.bottomToolbarHeight(tightVertical: tightVertical)))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
                .allowsHitTesting(false)
        }
    }

    private var saveCapsuleButton: some View {
        Button(action: onSave) {
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20))
                Text("Save")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, tightVertical ? 6 : 8)
            .padding(.horizontal, 6)
            .background(Capsule(style: .continuous).fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Save mock — enabled row becomes primary; disabled row stays off and keeps JSON")
    }

    private func toolbarPlainButton(
        title: String,
        systemImage: String,
        foreground: Color = Color.secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
    }
}

import KawarimiHengeCore
import SwiftUI

struct DetailColumnJsonEditorView: View {
    @Binding var bodyText: String
    let validationMessage: String?
    let tightVertical: Bool
    var focus: FocusState<DetailColumnFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: tightVertical ? 8 : 10) {
            darkJsonEditorChrome
            if let msg = validationMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(EditorValidation.isJsonErrorMessage(msg) ? .red : .secondary)
            }
        }
        .padding(.horizontal, tightVertical ? 10 : 16)
        .padding(.bottom, 8)
    }

    private var darkJsonEditorChrome: some View {
        let bodyLineCount = DetailColumnLayoutCore.jsonLineCount(body: bodyText.isEmpty ? nil : bodyText)
        let lineCount = DetailColumnLayoutCore.editorLineCount(bodyLineCount: bodyLineCount, tightVertical: tightVertical)
        let minBodyHeight = CGFloat(DetailColumnLayoutCore.jsonEditorMinBodyHeight(tightVertical: tightVertical))
        let contentHeight = CGFloat(DetailColumnLayoutCore.editorContentHeight(lineCount: lineCount))
        let editorFill = Color(red: 0.1, green: 0.11, blue: 0.13)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.green.opacity(0.85))
                        .frame(width: 8, height: 8)
                }
                Spacer(minLength: 0)
                Text("HENGE-EDITOR-V1")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, tightVertical ? 6 : 8)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.07, green: 0.075, blue: 0.09))

            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    JsonEditorLineNumberGutter(
                        lineCount: lineCount,
                        verticalPadding: tightVertical ? 6 : 8
                    )

                    TextEditor(text: $bodyText)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .background(editorFill)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .frame(minHeight: contentHeight)
                        .padding(.vertical, 4)
                        .padding(.trailing, 8)
                        .focused(focus, equals: .jsonBody)
                }
            }
            .frame(maxWidth: .infinity, minHeight: minBodyHeight, maxHeight: .infinity)
            .background(editorFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

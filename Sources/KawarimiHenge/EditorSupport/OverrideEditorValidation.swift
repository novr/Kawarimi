import Foundation

enum OverrideEditorValidation {
    static func isErrorValidationMessage(_ message: String) -> Bool {
        message.hasPrefix("Invalid")
    }
}

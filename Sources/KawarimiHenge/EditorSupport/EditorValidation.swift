import Foundation

enum EditorValidation {
    static func isInvalidJSONMessage(_ message: String) -> Bool {
        message.hasPrefix("Invalid")
    }
}

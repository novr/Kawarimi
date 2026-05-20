/// JSON body validation / format messages from ``OverrideEditorStore`` (single source for copy + error styling).
package enum EditorValidation {
    package static let validJSONMessage = "Valid JSON"
    package static let invalidJSONMessage = "Invalid JSON"
    package static let invalidJSONCannotFormatMessage = "Invalid JSON (cannot format)"
    package static let formattedMessage = "Formatted"

    /// Messages that should appear as errors under the JSON editor (not prefix heuristics).
    package static func isJsonErrorMessage(_ message: String) -> Bool {
        message == invalidJSONMessage || message == invalidJSONCannotFormatMessage
    }
}

/// JSON body validation / format messages from ``OverrideEditorStore`` (single source for copy + error styling).
enum EditorValidation {
    static let validJSONMessage = "Valid JSON"
    static let invalidJSONMessage = "Invalid JSON"
    static let invalidJSONCannotFormatMessage = "Invalid JSON (cannot format)"
    static let formattedMessage = "Formatted"

    /// Messages that should appear as errors under the JSON editor (not prefix heuristics).
    static func isJsonErrorMessage(_ message: String) -> Bool {
        message == invalidJSONMessage || message == invalidJSONCannotFormatMessage
    }
}

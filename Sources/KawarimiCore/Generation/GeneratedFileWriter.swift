import Foundation

package enum GeneratedFileWriter {
    @discardableResult
    package static func writeIfChanged(_ content: String, to url: URL) throws -> Bool {
        let parent = url.deletingLastPathComponent()
        precondition(
            FileManager.default.fileExists(atPath: parent.path),
            "Output directory does not exist: \(parent.path)"
        )
        if let existing = try? String(contentsOf: url, encoding: .utf8), existing == content {
            return false
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
        return true
    }
}

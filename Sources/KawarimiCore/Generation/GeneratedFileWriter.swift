import Foundation

package enum GeneratedFileWriter {
    package struct OutputDirectoryMissing: Error, CustomStringConvertible {
        package let path: String
        package var description: String { "Output directory does not exist: \(path)" }
    }

    @discardableResult
    package static func writeIfChanged(_ content: String, to url: URL) throws -> Bool {
        let parent = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parent.path) else {
            throw OutputDirectoryMissing(path: parent.path)
        }
        let newData = Data(content.utf8)
        if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
           size == newData.count,
           let existing = try? Data(contentsOf: url),
           existing == newData {
            return false
        }
        try newData.write(to: url, options: .atomic)
        return true
    }
}

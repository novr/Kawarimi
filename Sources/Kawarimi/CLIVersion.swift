import Foundation

enum CLIVersion {
    static let string: String = {
        guard let url = Bundle.module.url(forResource: "VERSION", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "unknown"
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : trimmed
    }()
}

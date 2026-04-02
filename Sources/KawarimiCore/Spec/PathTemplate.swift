import Foundation

/// `{param}` matches one path segment; counts must match segment-for-segment.
public enum PathTemplate {
    public static func matches(actual: String, template: String) -> Bool {
        let a = actual.split(separator: "/", omittingEmptySubsequences: false)
        let t = template.split(separator: "/", omittingEmptySubsequences: false)
        guard a.count == t.count else { return false }
        return zip(a, t).allSatisfy { segActual, segTemplate in
            segActual == segTemplate || (segTemplate.hasPrefix("{") && segTemplate.hasSuffix("}"))
        }
    }
}

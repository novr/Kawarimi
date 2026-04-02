import Foundation

/// `{param}` を 1 セグメント分のワイルドカードとみなし、セグメント数が一致するときだけマッチさせる。
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

import Foundation

/// OpenAPI の path テンプレート（例: `/api/items/{id}`）と実 path の一致判定。
public enum PathTemplate {
    /// 実リクエスト path がテンプレートに一致するか。`{param}` は任意の 1 セグメントにマッチする。
    public static func matches(actual: String, template: String) -> Bool {
        let a = actual.split(separator: "/", omittingEmptySubsequences: false)
        let t = template.split(separator: "/", omittingEmptySubsequences: false)
        guard a.count == t.count else { return false }
        return zip(a, t).allSatisfy { segActual, segTemplate in
            segActual == segTemplate || (segTemplate.hasPrefix("{") && segTemplate.hasSuffix("}"))
        }
    }
}

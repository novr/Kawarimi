import Foundation

/// よく使う HTTP メソッドにおけるリクエストボディの扱い（クライアント送信・UI 表示用）。
public enum HTTPRequestBodyPolicy {
    /// `Content-Type` / `httpBody` を付けるか。GET/HEAD 等では付けない。
    public static func shouldAttachRequestBody(method: String, bodyUTF8: Data?) -> Bool {
        let m = method.uppercased()
        switch m {
        case "GET", "HEAD", "OPTIONS", "TRACE", "CONNECT":
            return false
        case "POST", "PUT", "PATCH":
            return true
        case "DELETE":
            if let bodyUTF8, !bodyUTF8.isEmpty {
                return true
            }
            return false
        default:
            return false
        }
    }

    /// JSON ボディ入力 UI を出すか（DELETE は任意ボディのため表示）。
    public static func shouldShowJSONBodyEditor(method: String) -> Bool {
        let m = method.uppercased()
        switch m {
        case "POST", "PUT", "PATCH", "DELETE":
            return true
        default:
            return false
        }
    }
}

import Foundation

/// GET/HEAD 等へ body を付けるとサーバやプロキシで弾かれうるため、送信可否と UI を揃える。
public enum HTTPRequestBodyPolicy {
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

import Foundation
import HTTPTypes

/// GET/HEAD 等へ body を付けるとサーバやプロキシで弾かれうるため、送信可否と UI を揃える。
public enum HTTPRequestBodyPolicy {
    public static func shouldAttachRequestBody(method: HTTPRequest.Method, body: Data?) -> Bool {
        shouldAttachRequestBody(method: method.rawValue, body: body)
    }

    public static func shouldShowJSONBodyEditor(method: HTTPRequest.Method) -> Bool {
        shouldShowJSONBodyEditor(method: method.rawValue)
    }

    public static func shouldAttachRequestBody(method: String, body: Data?) -> Bool {
        let m = method.uppercased()
        switch m {
        case "GET", "HEAD", "OPTIONS", "TRACE", "CONNECT":
            return false
        case "POST", "PUT", "PATCH":
            return true
        case "DELETE":
            if let body, !body.isEmpty {
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

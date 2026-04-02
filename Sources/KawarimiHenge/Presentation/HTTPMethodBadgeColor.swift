import KawarimiCore
import SwiftUI

/// Fill colors for HTTP method pills, shared by KawarimiHenge and apps that mirror its explorer styling (e.g. DemoApp OpenAPI tab).
public enum HTTPMethodBadgeColor {
    public static func fill(for method: HTTPRequest.Method) -> Color {
        fill(for: method.rawValue)
    }

    public static func fill(for method: String) -> Color {
        switch method.uppercased() {
        case "GET": return Color(red: 0.22, green: 0.52, blue: 0.95)
        case "POST": return Color(red: 0.12, green: 0.52, blue: 0.32)
        case "PUT", "PATCH": return Color(red: 0.98, green: 0.58, blue: 0.12)
        case "DELETE": return Color(red: 0.92, green: 0.26, blue: 0.28)
        default: return Color(white: 0.55)
        }
    }
}

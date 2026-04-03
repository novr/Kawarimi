import Foundation

enum HTTPStatusPhrase {
    static func text(for statusCode: Int) -> String {
        switch statusCode {
        case 100: return "Continue"
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 409: return "Conflict"
        case 422: return "Unprocessable Entity"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default:
            return HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
        }
    }
}

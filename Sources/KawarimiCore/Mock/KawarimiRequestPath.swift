import Foundation

public enum KawarimiRequestPath {
    /// Request path without query or fragment (leading `/` preserved).
    public static func pathOnly(_ rawPath: String?) -> String {
        guard let rawPath, !rawPath.isEmpty else { return "/" }
        var path = rawPath
        if let queryStart = path.firstIndex(of: "?") {
            path = String(path[..<queryStart])
        } else if let fragmentStart = path.firstIndex(of: "#") {
            path = String(path[..<fragmentStart])
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        return path
    }
}

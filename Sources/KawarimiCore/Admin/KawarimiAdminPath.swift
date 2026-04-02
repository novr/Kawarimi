import Foundation

/// Only a full path segment `__kawarimi` counts (not e.g. `foo__kawarimi`).
public enum KawarimiAdminPath {
    public static let managementSegment = "__kawarimi"

    public static func isManagementRequestPath(_ path: String) -> Bool {
        path.split(separator: "/").contains { String($0) == managementSegment }
    }
}

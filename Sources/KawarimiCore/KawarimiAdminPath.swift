import Foundation

/// `__kawarimi` をパスセグメントとして含んでも、部分一致（`foo__kawarimi` 等）では管理 API とみなさない。
public enum KawarimiAdminPath {
    public static let managementSegment = "__kawarimi"

    public static func isManagementRequestPath(_ path: String) -> Bool {
        path.split(separator: "/").contains { String($0) == managementSegment }
    }
}

import Foundation

/// Kawarimi 管理 API（Henge）の URL パス判定。セグメントが **`__kawarimi` と完全一致**するときのみ管理パスとみなす。
public enum KawarimiAdminPath {
    public static let managementSegment = "__kawarimi"

    /// リクエストパスに管理用セグメント `__kawarimi` が含まれるか（例: `/api/__kawarimi/spec`, `/__kawarimi/configure`）。
    public static func isManagementRequestPath(_ path: String) -> Bool {
        path.split(separator: "/").contains { String($0) == managementSegment }
    }
}

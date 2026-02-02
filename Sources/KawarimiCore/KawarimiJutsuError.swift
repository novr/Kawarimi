import Foundation

public enum KawarimiJutsuError: Error, CustomStringConvertible {
    case specFileNotFound(path: String)
    case specFileInvalidEncoding
    case specParseError(String)

    public var description: String {
        switch self {
        case .specFileNotFound(let path): return "OpenAPI ファイルが見つかりません: \(path)"
        case .specFileInvalidEncoding: return "OpenAPI ファイルのエンコーディングが不正です"
        case .specParseError(let msg): return "OpenAPI のパースに失敗しました: \(msg)"
        }
    }
}

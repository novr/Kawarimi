import Foundation

public enum KawarimiJutsuError: Error, CustomStringConvertible {
    case specFileNotFound(path: String)
    case specFileInvalidEncoding
    case specParseError(String)
    case generatorConfigInvalid(path: String, reason: String)
    case handlerGenerationUnsupported(operationId: String, detail: String)

    public var description: String {
        switch self {
        case .specFileNotFound(let path): return "OpenAPI ファイルが見つかりません: \(path)"
        case .specFileInvalidEncoding: return "OpenAPI ファイルのエンコーディングが不正です"
        case .specParseError(let msg): return "OpenAPI のパースに失敗しました: \(msg)"
        case .generatorConfigInvalid(let path, let reason):
            return "openapi-generator-config の解釈に失敗しました (\(path)): \(reason)"
        case .handlerGenerationUnsupported(let operationId, let detail):
            return "KawarimiHandler を生成できません (operationId: \(operationId)): \(detail)"
        }
    }
}

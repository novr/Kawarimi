import Foundation

public enum KawarimiJutsuError: Error, CustomStringConvertible, LocalizedError {
    case specFileNotFound(path: String)
    case specFileInvalidEncoding
    case specParseError(String)
    case generatorConfigInvalid(path: String, reason: String)
    case handlerGenerationUnsupported(operationId: String, detail: String)
    case idiomaticNamingInvariantViolated(documentedName: String)

    public var description: String {
        switch self {
        case .specFileNotFound(let path): return "OpenAPI file not found: \(path)"
        case .specFileInvalidEncoding: return "OpenAPI file has invalid encoding"
        case .specParseError(let msg): return "Failed to parse OpenAPI: \(msg)"
        case .generatorConfigInvalid(let path, let reason):
            return "Failed to interpret openapi-generator-config (\(path)): \(reason)"
        case .handlerGenerationUnsupported(let operationId, let detail):
            return "Cannot generate KawarimiHandler (operationId: \(operationId)): \(detail)"
        case .idiomaticNamingInvariantViolated(let documentedName):
            return "Idiomatic OpenAPI naming invariant violated for operationId \"\(documentedName)\""
        }
    }

    public var errorDescription: String? { description }
}

import Foundation
import OpenAPIKit
import OpenAPIKit30
import OpenAPIKitCompat
import Yams

enum OpenAPIDocumentLoader {
    static func load(path: String) throws -> OpenAPIKit.OpenAPI.Document {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw KawarimiJutsuError.specFileNotFound(path: path)
        }
        return try load(data: data, sourcePath: path)
    }

    static func load(data: Data, sourcePath: String) throws -> OpenAPIKit.OpenAPI.Document {
        let decoder = YAMLDecoder()
        struct OpenAPIVersionedDocument: Decodable { var openapi: String? }
        let decodingOptions: [CodingUserInfoKey: Any] = [
            OpenAPIKit.DocumentConfiguration.versionMapKey: [
                "3.2.0": OpenAPIKit.OpenAPI.Document.Version.v3_1_2,
            ],
        ]
        let versionedDocument: OpenAPIVersionedDocument
        do {
            versionedDocument = try decoder.decode(OpenAPIVersionedDocument.self, from: data)
        } catch {
            throw KawarimiJutsuError.specParseError(String(describing: error))
        }
        guard let openAPIVersion = versionedDocument.openapi else {
            throw KawarimiJutsuError.specParseError(
                "No key named openapi found. Please provide a valid OpenAPI document with OpenAPI versions in the 3.0.x, 3.1.x, or 3.2.x sets."
            )
        }
        do {
            switch openAPIVersion {
            case "3.0.0", "3.0.1", "3.0.2", "3.0.3", "3.0.4":
                let openAPI30Document = try decoder.decode(OpenAPIKit30.OpenAPI.Document.self, from: data)
                return openAPI30Document.convert(to: .v3_1_0)
            case "3.1.0", "3.1.1", "3.1.2":
                return try decoder.decode(OpenAPIKit.OpenAPI.Document.self, from: data)
            case "3.2.0":
                return try decoder.decode(OpenAPIKit.OpenAPI.Document.self, from: data, userInfo: decodingOptions)
            default:
                throw KawarimiJutsuError.specParseError(
                    "Unsupported document version: openapi: \(openAPIVersion). Please provide a document with OpenAPI versions in the 3.0.x, 3.1.x, or 3.2.x sets."
                )
            }
        } catch let err as KawarimiJutsuError {
            throw err
        } catch {
            throw KawarimiJutsuError.specParseError(String(describing: error))
        }
    }
}

import Foundation
import KawarimiCore
import OpenAPIKit

enum OpenAPIParameterSpecSupport {
    static func specParameters(
        pathItem: OpenAPI.Parameter.Array,
        operation: OpenAPI.Parameter.Array,
        components: OpenAPI.Components
    ) -> [SpecParameter]? {
        let pathItemParams = specParameters(from: pathItem, components: components)
        let operationParams = specParameters(from: operation, components: components)
        return SpecParameter.merge(pathItem: pathItemParams, operation: operationParams)
    }

    private static func specParameters(
        from array: OpenAPI.Parameter.Array,
        components: OpenAPI.Components
    ) -> [SpecParameter] {
        array.compactMap { specParameter(from: $0, components: components) }
    }

    private static func specParameter(
        from either: Either<OpenAPI.Reference<OpenAPI.Parameter>, OpenAPI.Parameter>,
        components: OpenAPI.Components
    ) -> SpecParameter? {
        guard let parameter = components[either] else { return nil }
        return specParameter(from: parameter, components: components)
    }

    private static func specParameter(
        from parameter: OpenAPI.Parameter,
        components: OpenAPI.Components
    ) -> SpecParameter? {
        let location: SpecParameterLocation
        switch parameter.context.location {
        case .path:
            location = .path
        case .query:
            location = .query
        case .header:
            location = .header
        case .cookie:
            return nil
        }

        let schemaType: String?
        switch parameter.schemaOrContent {
        case .a(let schemaContext):
            guard let schema = components[schemaContext.schema] else {
                schemaType = nil
                break
            }
            schemaType = schemaPrimaryTypeLabel(schema: schema, components: components)
        case .b:
            return nil
        }

        return SpecParameter(
            location: location,
            name: parameter.name,
            required: parameter.context.required,
            description: parameter.description,
            schemaType: schemaType
        )
    }

    static func schemaPrimaryTypeLabel(schema: JSONSchema, components: OpenAPI.Components) -> String? {
        var refChain: Set<OpenAPI.ComponentKey> = []
        guard let resolved = resolveSchemaForPrimaryType(schema, components: components, refChain: &refChain) else {
            return nil
        }
        switch resolved.value {
        case .all, .one, .any, .not, .reference:
            return nil
        default:
            return resolved.jsonType?.rawValue
        }
    }

    private static func resolveSchemaForPrimaryType(
        _ schema: JSONSchema,
        components: OpenAPI.Components,
        refChain: inout Set<OpenAPI.ComponentKey>
    ) -> JSONSchema? {
        if case .reference(let ref, _) = schema.value,
           let name = ref.name,
           let key = OpenAPI.ComponentKey(rawValue: name)
        {
            if refChain.contains(key) { return nil }
            guard let inner = components.schemas[key] else { return nil }
            refChain.insert(key)
            defer { refChain.remove(key) }
            return resolveSchemaForPrimaryType(inner, components: components, refChain: &refChain)
        }
        return schema
    }
}

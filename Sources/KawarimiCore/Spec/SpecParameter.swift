import Foundation

public enum SpecParameterLocation: String, Codable, Sendable, Comparable {
    case path
    case query
    case header

    public static func < (lhs: SpecParameterLocation, rhs: SpecParameterLocation) -> Bool {
        let order: [SpecParameterLocation] = [.path, .query, .header]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

public protocol SpecParameterProviding: Sendable {
    var location: SpecParameterLocation { get }
    var name: String { get }
    var required: Bool { get }
    var description: String? { get }
    var schemaType: String? { get }
}

public struct SpecParameter: Codable, Sendable, SpecParameterProviding {
    public var location: SpecParameterLocation
    public var name: String
    public var required: Bool
    public var description: String?
    public var schemaType: String?

    public init(
        location: SpecParameterLocation,
        name: String,
        required: Bool,
        description: String? = nil,
        schemaType: String? = nil
    ) {
        self.location = location
        self.name = name
        self.required = required
        self.description = description
        self.schemaType = schemaType
    }
}

extension SpecParameter {
    /// Merges path-item and operation parameters; operation wins on `(location, name)`. Returns `nil` when empty.
    public static func merge(pathItem: [SpecParameter], operation: [SpecParameter]) -> [SpecParameter]? {
        var byKey: [String: SpecParameter] = [:]
        func key(for parameter: SpecParameter) -> String {
            "\(parameter.location.rawValue):\(parameter.name)"
        }
        for parameter in pathItem {
            byKey[key(for: parameter)] = parameter
        }
        for parameter in operation {
            byKey[key(for: parameter)] = parameter
        }
        guard !byKey.isEmpty else { return nil }
        return byKey.values.sorted { lhs, rhs in
            if lhs.location != rhs.location { return lhs.location < rhs.location }
            return lhs.name < rhs.name
        }
    }
}

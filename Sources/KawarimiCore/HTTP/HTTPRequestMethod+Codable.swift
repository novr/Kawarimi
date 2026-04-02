import Foundation
import HTTPTypes

extension HTTPRequest.Method: @retroactive Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        let normalized = str.uppercased()
        guard let method = HTTPRequest.Method(normalized) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid HTTP method token: \(str)"
            )
        }
        self = method
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.uppercased())
    }
}

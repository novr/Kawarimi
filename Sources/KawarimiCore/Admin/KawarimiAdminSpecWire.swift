import Foundation

public enum KawarimiAdminSpecWire {
    /// Throws if `data` is not decodable as ``HengeSpecSnapshot`` (GET …/spec wire contract).
    public static func validate(_ data: Data) throws {
        _ = try JSONDecoder().decode(HengeSpecSnapshot.self, from: data)
    }
}

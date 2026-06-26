import Foundation

public enum KawarimiScenarioTokens {
    public static func normalize(_ raw: String?) -> String? {
        guard let token = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard token.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return token
    }
}

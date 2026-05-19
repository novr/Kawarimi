#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

public enum StandardError {
    public static func write(_ message: String) {
        var line = message
        if !line.hasSuffix("\n") {
            line += "\n"
        }
        line.withCString { cString in
            let length = strlen(cString)
#if canImport(Glibc)
            _ = Glibc.write(2, cString, length)
#else
            _ = Darwin.write(2, cString, length)
#endif
        }
    }
}

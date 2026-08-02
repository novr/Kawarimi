#if os(macOS) || os(Linux)
import DemoAPI
import Foundation
import KawarimiCore

@main
enum DemoSpecWireExport {
    static func main() throws {
        let response = SpecResponse(
            meta: KawarimiSpec.meta,
            endpoints: KawarimiSpec.endpoints,
            securitySchemes: KawarimiSpec.securitySchemes
        )
        let data = try JSONEncoder().encode(response)
        try KawarimiAdminSpecWire.validate(data)
        try FileHandle.standardOutput.write(contentsOf: data)
    }
}
#else
@main
enum DemoSpecWireExport {
    static func main() {
        fputs("DemoSpecWireExport is only supported on macOS and Linux\n", stderr)
    }
}
#endif

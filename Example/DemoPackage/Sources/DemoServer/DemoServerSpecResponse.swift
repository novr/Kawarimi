#if os(macOS) || os(Linux)
import DemoAPI
import Foundation
import KawarimiCore

enum DemoServerSpecResponse {
    static func current() -> SpecResponse {
        SpecResponse(
            meta: KawarimiSpec.meta,
            endpoints: KawarimiSpec.endpoints,
            securitySchemes: KawarimiSpec.securitySchemes
        )
    }

    static func encodedWireData() throws -> Data {
        try JSONEncoder().encode(current())
    }

    static func validateWireAtStartup() throws {
        try KawarimiAdminSpecWire.validate(try encodedWireData())
    }
}
#endif

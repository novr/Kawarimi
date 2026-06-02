import Foundation
import KawarimiCore
import Testing

@Test func kawarimiAdminSpecWireValidateAcceptsFixture() throws {
    guard let url = Bundle.module.url(
        forResource: "henge-spec-snapshot",
        withExtension: "json",
        subdirectory: "Fixtures"
    ) else {
        Issue.record("henge-spec-snapshot.json not found in test resources")
        return
    }
    let data = try Data(contentsOf: url)
    try KawarimiAdminSpecWire.validate(data)
}

@Test func kawarimiAdminSpecWireValidateRejectsEmptyData() {
    #expect(throws: DecodingError.self) {
        try KawarimiAdminSpecWire.validate(Data())
    }
}

@Test func kawarimiAdminSpecWireValidateRejectsInvalidJSON() {
    #expect(throws: DecodingError.self) {
        try KawarimiAdminSpecWire.validate("{".data(using: .utf8)!)
    }
}

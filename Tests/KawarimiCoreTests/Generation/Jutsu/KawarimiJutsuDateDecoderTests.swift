import Foundation
@testable import KawarimiJutsu
import Testing

private struct DateDecodePayload: Decodable {
    let value: Date
}

@Test func stubJSONDecoderDecodesDateTimeLikeParseOpenAPIExample() throws {
    let source = "2025-02-14T00:30:00Z"
    let expected = try #require(OpenAPIDateMockSupport.parseOpenAPIDateExample(source, dateOnly: false))
    let data = #"{"value":"\#(source)"}"#.data(using: .utf8)!
    let decoded = try OpenAPIDateMockSupport.stubJSONDecoder().decode(DateDecodePayload.self, from: data)
    #expect(decoded.value == expected)
}

@Test func stubJSONDecoderDecodesDateOnlyLikeParseOpenAPIExample() throws {
    let source = "2025-02-14"
    let expected = try #require(OpenAPIDateMockSupport.parseOpenAPIDateExample(source, dateOnly: true))
    let data = #"{"value":"\#(source)"}"#.data(using: .utf8)!
    let decoded = try OpenAPIDateMockSupport.stubJSONDecoder().decode(DateDecodePayload.self, from: data)
    #expect(decoded.value == expected)
}

@Test func stubJSONDecoderThrowsForUnparseableDateString() throws {
    let data = #"{"value":"not-a-valid-date"}"#.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
        _ = try OpenAPIDateMockSupport.stubJSONDecoder().decode(DateDecodePayload.self, from: data)
    }
}

@Test func generatedStubDecoderSourceContainsExpectedDebugDescription() {
    let source = OpenAPIDateMockSupport.generatedStubJSONDecoderMethodSource()
    #expect(source.contains("Kawarimi stub JSONDecoder: unparseable date string"))
}

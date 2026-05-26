import Foundation
import KawarimiCore
import Testing

@Test func specParameterMergeOperationOverridesPathItem() {
    let pathItem = [
        SpecParameter(location: .query, name: "limit", required: false, description: "path", schemaType: "integer"),
    ]
    let operation = [
        SpecParameter(location: .query, name: "limit", required: true, description: "op", schemaType: "string"),
    ]
    let merged = SpecParameter.merge(pathItem: pathItem, operation: operation)
    #expect(merged?.count == 1)
    #expect(merged?.first?.required == true)
    #expect(merged?.first?.description == "op")
    #expect(merged?.first?.schemaType == "string")
}

@Test func specParameterMergeEmptyReturnsNil() {
    #expect(SpecParameter.merge(pathItem: [], operation: []) == nil)
}

@Test func specParameterMergeSortsByLocationThenName() {
    let merged = SpecParameter.merge(
        pathItem: [
            SpecParameter(location: .header, name: "X-Trace", required: false),
            SpecParameter(location: .path, name: "id", required: true),
        ],
        operation: [
            SpecParameter(location: .query, name: "limit", required: false),
            SpecParameter(location: .query, name: "name", required: false),
        ]
    )
    #expect(merged?.map(\.name) == ["id", "limit", "name", "X-Trace"])
    #expect(merged?.map(\.location) == [.path, .query, .query, .header])
}

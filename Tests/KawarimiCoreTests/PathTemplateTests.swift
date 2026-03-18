import KawarimiCore
import Testing

@Test func pathTemplateExactMatch() {
    #expect(PathTemplate.matches(actual: "/api/greet", template: "/api/greet"))
    #expect(PathTemplate.matches(actual: "/api/items", template: "/api/items"))
}

@Test func pathTemplateSingleParameter() {
    #expect(PathTemplate.matches(actual: "/api/items/123", template: "/api/items/{id}"))
    #expect(PathTemplate.matches(actual: "/api/items/abc", template: "/api/items/{id}"))
    #expect(PathTemplate.matches(actual: "/api/tags/xyz", template: "/api/tags/{id}"))
}

@Test func pathTemplateMultipleSegments() {
    #expect(PathTemplate.matches(actual: "/api/items/item-1/metadata", template: "/api/items/{id}/metadata"))
    #expect(!PathTemplate.matches(actual: "/api/items/item-1/extra/metadata", template: "/api/items/{id}/metadata"))
}

@Test func pathTemplateMismatchLength() {
    #expect(!PathTemplate.matches(actual: "/api/items", template: "/api/items/{id}"))
    #expect(!PathTemplate.matches(actual: "/api/items/123/foo", template: "/api/items/{id}"))
}

@Test func pathTemplateLiteralSegmentMismatch() {
    #expect(!PathTemplate.matches(actual: "/api/items/123", template: "/api/tags/{id}"))
    #expect(!PathTemplate.matches(actual: "/api/items/123/metadata", template: "/api/items/{id}/other"))
}

@Test func pathTemplateLeadingSlash() {
    #expect(PathTemplate.matches(actual: "/api/greet", template: "/api/greet"))
}

@Test func pathTemplateEmptySegments() {
    #expect(PathTemplate.matches(actual: "/", template: "/"))
}

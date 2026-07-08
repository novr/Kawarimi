import KawarimiCore
import Testing

@Test(.timeLimit(.minutes(1))) func pathTemplateExactMatch() {
    #expect(PathTemplate.matches(actual: "/api/greet", template: "/api/greet"))
    #expect(PathTemplate.matches(actual: "/api/items", template: "/api/items"))
}

@Test(.timeLimit(.minutes(1))) func pathTemplateSingleParameter() {
    #expect(PathTemplate.matches(actual: "/api/items/123", template: "/api/items/{id}"))
    #expect(PathTemplate.matches(actual: "/api/items/abc", template: "/api/items/{id}"))
    #expect(PathTemplate.matches(actual: "/api/tags/xyz", template: "/api/tags/{id}"))
}

@Test(.timeLimit(.minutes(1))) func pathTemplateMultipleSegments() {
    #expect(PathTemplate.matches(actual: "/api/items/item-1/metadata", template: "/api/items/{id}/metadata"))
    #expect(!PathTemplate.matches(actual: "/api/items/item-1/extra/metadata", template: "/api/items/{id}/metadata"))
}

@Test(.timeLimit(.minutes(1))) func pathTemplateMultipleParameters() {
    #expect(PathTemplate.matches(actual: "/api/foo/bar", template: "/api/{a}/{b}"))
    #expect(PathTemplate.matches(actual: "/api/items/tags", template: "/api/{type}/{id}"))
    #expect(!PathTemplate.matches(actual: "/api/foo", template: "/api/{a}/{b}"))
    #expect(!PathTemplate.matches(actual: "/api/foo/bar/baz", template: "/api/{a}/{b}"))
}

@Test(.timeLimit(.minutes(1))) func pathTemplateMismatchLength() {
    #expect(!PathTemplate.matches(actual: "/api/items", template: "/api/items/{id}"))
    #expect(!PathTemplate.matches(actual: "/api/items/123/foo", template: "/api/items/{id}"))
}

@Test(.timeLimit(.minutes(1))) func pathTemplateLiteralSegmentMismatch() {
    #expect(!PathTemplate.matches(actual: "/api/items/123", template: "/api/tags/{id}"))
    #expect(!PathTemplate.matches(actual: "/api/items/123/metadata", template: "/api/items/{id}/other"))
}

@Test(.timeLimit(.minutes(1))) func pathTemplateLeadingSlash() {
    #expect(PathTemplate.matches(actual: "/api/greet", template: "/api/greet"))
}

@Test(.timeLimit(.minutes(1))) func pathTemplateEmptySegments() {
    #expect(PathTemplate.matches(actual: "/", template: "/"))
}

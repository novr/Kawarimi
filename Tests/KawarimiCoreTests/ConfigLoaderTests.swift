import Foundation
import KawarimiCore
import Testing

@Test func configLoaderLoadReturnsNilWhenFileMissing() {
    let result = ConfigLoader.load(configPath: "/nonexistent/kawarimi.yaml")
    #expect(result == nil)
}

@Test func configLoaderLoadFromConfigPathReturnsConfigWhenFileExists() throws {
    guard let url = Bundle.module.url(forResource: "kawarimi", withExtension: "yaml") else {
        Issue.record("kawarimi.yaml がテストリソースに見つかりません")
        return
    }
    let result = ConfigLoader.load(configPath: url.path())
    #expect(result != nil)
    #expect(result?.generate == ["types"])
}

@Test func configLoaderLoadFromOpenAPIPathFindsKawarimiInSameDir() throws {
    guard let openapiURL = Bundle.module.url(forResource: "openapi", withExtension: "yaml") else {
        Issue.record("openapi.yaml がテストリソースに見つかりません")
        return
    }
    let result = ConfigLoader.load(openapiPath: openapiURL.path())
    #expect(result != nil)
    #expect(result?.generate == ["types"])
}

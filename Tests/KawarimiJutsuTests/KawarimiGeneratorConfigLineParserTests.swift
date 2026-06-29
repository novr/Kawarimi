import Foundation
import KawarimiJutsu
import Testing

@Test func lineParserDefaultsWhenConfigMissing() throws {
    let options = try KawarimiGeneratorConfigLineParser.load(kawarimiConfigURL: nil)
    #expect(options == .defaults)
    #expect(options.outputFileNames == ["Kawarimi.swift", "KawarimiHandler.swift", "KawarimiSpec.swift"])
}

@Test func lineParserAcceptsTrueFalseOnly() {
    let text = """
    generateKawarimi: true
    generateHandler: false
    generateSpec: true
    """
    let options = KawarimiGeneratorConfigLineParser.parseOutputOptions(from: text)
    #expect(options.generateKawarimi)
    #expect(!options.generateHandler)
    #expect(options.generateSpec)
    #expect(options.outputFileNames == ["Kawarimi.swift", "KawarimiSpec.swift"])
}

@Test func lineParserIgnoresNonBooleanSynonyms() {
    let text = """
    generateKawarimi: yes
    generateHandler: on
    generateSpec: false
    """
    let options = KawarimiGeneratorConfigLineParser.parseOutputOptions(from: text)
    #expect(options.generateKawarimi)
    #expect(options.generateHandler)
    #expect(!options.generateSpec)
}

@Test func lineParserRejectsAllOutputsDisabled() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kw-plugin-support-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let configURL = tmp.appendingPathComponent("kawarimi-generator-config.yaml")
    try """
    generateKawarimi: false
    generateHandler: false
    generateSpec: false
    """.write(to: configURL, atomically: true, encoding: .utf8)

    #expect(throws: KawarimiGeneratorConfigLineParserError.self) {
        _ = try KawarimiGeneratorConfigLineParser.load(kawarimiConfigURL: configURL)
    }
}

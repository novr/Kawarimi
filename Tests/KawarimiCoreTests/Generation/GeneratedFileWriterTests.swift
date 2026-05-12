import Foundation
import Testing
@testable import KawarimiCore

@Test func writeIfChangedSkipsWriteWhenContentIsSame() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeneratedFileWriterTests-same-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let target = dir.appendingPathComponent("Out.swift")
    let content = "public struct Kawarimi {}\n"
    try content.write(to: target, atomically: true, encoding: .utf8)

    let didWrite = try GeneratedFileWriter.writeIfChanged(content, to: target)
    let written = try String(contentsOf: target, encoding: .utf8)

    #expect(didWrite == false)
    #expect(written == content)
}

@Test func writeIfChangedOverwritesWhenContentDiffers() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeneratedFileWriterTests-diff-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let target = dir.appendingPathComponent("Out.swift")
    try "before\n".write(to: target, atomically: true, encoding: .utf8)

    let didWrite = try GeneratedFileWriter.writeIfChanged("after\n", to: target)
    let written = try String(contentsOf: target, encoding: .utf8)

    #expect(didWrite == true)
    #expect(written == "after\n")
}

@Test func writeIfChangedPreservesMtimeWhenContentIsSame() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeneratedFileWriterTests-mtime-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let target = dir.appendingPathComponent("Out.swift")
    let content = "unchanged\n"
    try content.write(to: target, atomically: true, encoding: .utf8)

    let pastDate = Date(timeIntervalSinceNow: -60)
    try FileManager.default.setAttributes(
        [.modificationDate: pastDate],
        ofItemAtPath: target.path
    )

    let mtimeBefore = try FileManager.default
        .attributesOfItem(atPath: target.path)[.modificationDate] as! Date

    let didWrite = try GeneratedFileWriter.writeIfChanged(content, to: target)

    let mtimeAfter = try FileManager.default
        .attributesOfItem(atPath: target.path)[.modificationDate] as! Date

    #expect(didWrite == false)
    #expect(mtimeBefore == mtimeAfter)
}

@Test func writeIfChangedCreatesNewFile() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeneratedFileWriterTests-new-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let target = dir.appendingPathComponent("New.swift")
    let content = "new file\n"

    let didWrite = try GeneratedFileWriter.writeIfChanged(content, to: target)
    let written = try String(contentsOf: target, encoding: .utf8)

    #expect(didWrite == true)
    #expect(written == content)
}

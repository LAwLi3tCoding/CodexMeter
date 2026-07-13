import Foundation
import CodexMeterCore

let codexExecutableLocator: [HarnessTest] = [
    HarnessTest(
        suite: "protocol",
        name: "Executable locator accepts an executable candidate",
        body: testExecutableCandidate
    ),
    HarnessTest(
        suite: "protocol",
        name: "Executable locator rejects missing candidates",
        body: testMissingExecutable
    )
]

private func testExecutableCandidate() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let executable = root.appendingPathComponent("codex")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try Data("#!/bin/sh\n".utf8).write(to: executable)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: executable.path
    )

    let located = try CodexExecutableLocator(candidatePaths: [executable.path]).locate()
    expectEqual(located.path, executable.path)
}

private func testMissingExecutable() {
    do {
        _ = try CodexExecutableLocator(candidatePaths: ["/missing/codex"]).locate()
        TestRecorder.record("expected locator to throw")
    } catch let error as CodexExecutableLocatorError {
        expectEqual(error, .notFound)
    } catch {
        TestRecorder.record("unexpected error: \(error)")
    }
}

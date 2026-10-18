import XCTest
@testable import ClaudePulse

final class HookInstallerTests: XCTestCase {
    private let exe = "/Applications/ClaudePulse.app/Contents/MacOS/ClaudePulse"

    private func json(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func commands(_ settings: [String: Any], _ event: String) -> [String] {
        let groups = (settings["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        return groups.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
    }

    func testInstallIntoNothingCreatesAllEvents() throws {
        let out = try json(HookInstaller.install(into: nil, executablePath: exe))
        for event in HookInstaller.events {
            XCTAssertEqual(commands(out, event), ["\"\(exe)\" --hook \(event) \(HookInstaller.marker)"])
        }
        XCTAssertEqual(try json(HookInstaller.install(into: Data(), executablePath: exe)).count, 1)
    }

    func testExistingHooksAndKeysPreserved() throws {
        let existing = #"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#
        let out = try json(HookInstaller.install(into: Data(existing.utf8), executablePath: exe))
        XCTAssertEqual(out["model"] as? String, "opus")
        XCTAssertEqual(commands(out, "Stop").first, "say done")
        XCTAssertEqual(commands(out, "Stop").count, 2)
    }

    func testInstallTwiceDoesNotDuplicate() throws {
        let once = try HookInstaller.install(into: nil, executablePath: exe)
        let twice = try HookInstaller.install(into: once, executablePath: "/new/path/ClaudePulse")
        let expected = "\"/new/path/ClaudePulse\" --hook Stop \(HookInstaller.marker)"
        XCTAssertEqual(commands(try json(twice), "Stop"), [expected])
    }

    func testRemoveDeletesOnlyMarkedEntriesAndPrunesEmpty() throws {
        let existing = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#
        let installed = try HookInstaller.install(into: Data(existing.utf8), executablePath: exe)
        let out = try json(HookInstaller.remove(from: installed))
        XCTAssertEqual(commands(out, "Stop"), ["say done"])
        XCTAssertNil((out["hooks"] as? [String: Any])?["SessionEnd"])
    }

    func testIsInstalled() throws {
        XCTAssertFalse(HookInstaller.isInstalled(in: nil))
        XCTAssertTrue(HookInstaller.isInstalled(in: try HookInstaller.install(into: nil, executablePath: exe)))
    }

    func testMalformedThrows() {
        XCTAssertThrowsError(try HookInstaller.install(into: Data("{oops".utf8), executablePath: exe))
        XCTAssertThrowsError(try HookInstaller.remove(from: Data("[1,2]".utf8)))
    }

    func testInstallToDiskFollowsSymlinkAndLeavesMalformedUntouched() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let real = dir.appendingPathComponent("real.json")
        let link = dir.appendingPathComponent("settings.json")
        try Data("{}".utf8).write(to: real)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        try HookInstaller.installToDisk(settingsURL: link, executablePath: exe)
        XCTAssertEqual((try FileManager.default.destinationOfSymbolicLink(atPath: link.path)), real.path)
        XCTAssertTrue(HookInstaller.isInstalled(in: try Data(contentsOf: real)))

        let bad = dir.appendingPathComponent("bad.json")
        try Data("{oops".utf8).write(to: bad)
        XCTAssertThrowsError(try HookInstaller.installToDisk(settingsURL: bad, executablePath: exe))
        XCTAssertEqual(try String(contentsOf: bad), "{oops")
    }

    func testInstallToDiskPreservesFilePermissions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("settings.json")
        try Data("{}".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        try HookInstaller.installToDisk(settingsURL: file, executablePath: exe)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
        try HookInstaller.removeFromDisk(settingsURL: file)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
    }

    func testUnreadableSettingsAreNotOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            let path = dir.appendingPathComponent("s.json").path
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            try? FileManager.default.removeItem(at: dir)
        }
        let file = dir.appendingPathComponent("s.json")
        try Data(#"{"model":"opus"}"#.utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        XCTAssertThrowsError(try HookInstaller.installToDisk(settingsURL: file, executablePath: exe))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        XCTAssertEqual(try String(contentsOf: file), #"{"model":"opus"}"#)
    }
}

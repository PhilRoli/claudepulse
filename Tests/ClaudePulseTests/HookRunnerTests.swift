import XCTest
@testable import ClaudePulse

final class HookRunnerTests: XCTestCase {
    private var dir: URL!
    private let now = Date(timeIntervalSince1970: 5_000)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func run(_ hook: String, _ json: String, directory: URL? = nil) -> Int32 {
        HookRunner.run(arguments: ["--hook", hook], stdin: Data(json.utf8),
                       directory: directory ?? dir, now: now, pid: 42)
    }

    private func files() -> [String] {
        let all = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return all.filter { $0.hasSuffix(".json") }.sorted()
    }

    func testStopWritesFinishedRecord() throws {
        XCTAssertEqual(run("Stop", #"{"session_id":"a","cwd":"/p"}"#), 0)
        XCTAssertEqual(files(), ["a.json"])
        let data = try Data(contentsOf: dir.appendingPathComponent("a.json"))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(SessionRecord.self, from: data)
        XCTAssertEqual(record.state, .finished)
        XCTAssertEqual(record.pid, 42)
        XCTAssertEqual(record.cwd, "/p")
    }

    func testSessionEndDeletesFile() {
        _ = run("Stop", #"{"session_id":"a","cwd":"/p"}"#)
        XCTAssertEqual(run("SessionEnd", #"{"session_id":"a","cwd":"/p"}"#), 0)
        XCTAssertEqual(files(), [])
    }

    func testBadInputExitsZeroAndWritesNothing() {
        XCTAssertEqual(run("Stop", ""), 0)
        XCTAssertEqual(run("Stop", "not json"), 0)
        XCTAssertEqual(run("Stop", #"{"cwd":"/p"}"#), 0)
        XCTAssertEqual(run("Bogus", #"{"session_id":"a","cwd":"/p"}"#), 0)
        XCTAssertEqual(files(), [])
    }

    func testUnwritableDirectoryExitsZero() {
        let bad = URL(fileURLWithPath: "/dev/null/nope")
        XCTAssertEqual(run("Stop", #"{"session_id":"a","cwd":"/p"}"#, directory: bad), 0)
    }

    func testSessionIDCannotEscapeDirectory() {
        XCTAssertEqual(run("Stop", #"{"session_id":"../evil","cwd":"/p"}"#), 0)
        XCTAssertEqual(files(), [])
    }

    func testConcurrentSubagentStartsAreNotLost() throws {
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            _ = run("SubagentStart", #"{"session_id":"a","cwd":"/p"}"#)
        }
        let data = try Data(contentsOf: dir.appendingPathComponent("a.json"))
        XCTAssertEqual(SessionStore.decode(data)?.subagents, 20)
    }

    func testEventMapping() {
        XCTAssertEqual(HookRunner.eventFrom(hookName: "Notification", payload: ["notification_type": "idle_prompt"]),
                       .notification(.idleReminder))
        XCTAssertEqual(HookRunner.eventFrom(hookName: "Notification",
                                            payload: ["notification_type": "permission_prompt"]),
                       .notification(.needsInput))
        XCTAssertEqual(HookRunner.eventFrom(hookName: "Notification",
                                            payload: ["notification_type": "elicitation_dialog"]),
                       .notification(.needsInput))
        XCTAssertEqual(HookRunner.eventFrom(hookName: "Notification", payload: ["notification_type": "auth_success"]),
                       .notification(.other))
        XCTAssertEqual(HookRunner.eventFrom(hookName: "Notification", payload: [:]), .notification(.needsInput))
        XCTAssertEqual(HookRunner.eventFrom(hookName: "SubagentStop", payload: [:]), .subagentStop)
        XCTAssertEqual(HookRunner.eventFrom(hookName: "PostToolUse", payload: [:]), .postToolUse)
        XCTAssertNil(HookRunner.eventFrom(hookName: "Bogus", payload: [:]))
    }
}

final class SessionTitleTests: XCTestCase {
    func testLastCustomTitleWins() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let lines = [#"{"type":"user"}"#, #"{"type":"custom-title","customTitle":"old","sessionId":"a"}"#,
                     #"{"type":"custom-title","customTitle":"new","sessionId":"a"}"#, #"{"type":"user"}"#]
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        XCTAssertEqual(HookRunner.transcriptValue(path: url.path, type: "custom-title", key: "customTitle"), "new")
        XCTAssertNil(HookRunner.transcriptValue(path: "/nonexistent", type: "custom-title", key: "customTitle"))
    }
}

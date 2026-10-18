import XCTest
@testable import ClaudePulse

final class SessionStoreTests: XCTestCase {
    private var dir: URL!
    private var current = Date(timeIntervalSince1970: 1_000_000)
    private var alive: Set<Int32> = [1]

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func store() -> SessionStore {
        SessionStore(directory: dir, isAlive: { [unowned self] in self.alive.contains($0) },
                     now: { [unowned self] in self.current })
    }

    private func write(_ id: String, state: SessionState = .working, pid: Int32? = 1, age: TimeInterval = 0) throws {
        let record = SessionRecord(sessionID: id, cwd: "/p/\(id)", pid: pid, terminalID: nil, state: state,
                                   subagents: 0, seen: false, updatedAt: current.addingTimeInterval(-age))
        try SessionStore.encode(record).write(to: dir.appendingPathComponent("\(id).json"))
    }

    private var onDisk: [String] { ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted() }

    func testCorruptFileIsSkipped() throws {
        try write("a")
        try Data("{oops".utf8).write(to: dir.appendingPathComponent("bad.json"))
        XCTAssertEqual(store().load().map(\.sessionID), ["a"])
    }

    func testDeadPidIsPrunedFromDisk() throws {
        try write("a", pid: 1)
        try write("b", pid: 99)
        XCTAssertEqual(store().load().map(\.sessionID), ["a"])
        XCTAssertEqual(onDisk, ["a.json"])
    }

    func testOldRecordWithoutPidIsPruned() throws {
        try write("old", pid: nil, age: 13 * 3600)
        try write("fresh", pid: nil, age: 60)
        XCTAssertEqual(store().load().map(\.sessionID), ["fresh"])
        XCTAssertEqual(onDisk, ["fresh.json"])
    }

    func testMarkSeenOnlyAffectsFinished() throws {
        try write("w", state: .working)
        try write("f", state: .finished)
        let s = store()
        s.markSeen(sessionID: "w")
        s.markSeen(sessionID: "f")
        let loaded = Dictionary(uniqueKeysWithValues: s.load().map { ($0.sessionID, $0) })
        XCTAssertEqual(loaded["w"]?.seen, false)
        XCTAssertEqual(loaded["f"]?.seen, true)
    }

    func testMissingDirectoryLoadsEmpty() {
        let s = SessionStore(directory: dir.appendingPathComponent("nope"))
        XCTAssertEqual(s.load(), [])
    }

    func testClearAllRemovesRecordsAndLocks() throws {
        try write("a")
        try write("b")
        FileManager.default.createFile(atPath: dir.appendingPathComponent("a.lock").path, contents: nil)
        store().clearAll()
        XCTAssertEqual(onDisk, [])
        XCTAssertEqual(store().load(), [])
    }

    func testDuplicateSessionIDsLoadOnce() throws {
        try write("a")
        try FileManager.default.copyItem(at: dir.appendingPathComponent("a.json"),
                                         to: dir.appendingPathComponent("a 2.json"))
        XCTAssertEqual(store().load().map(\.sessionID), ["a"])
    }

    func testSessionEndAndPruneRemoveLockFile() throws {
        try write("dead", pid: 99)
        FileManager.default.createFile(atPath: dir.appendingPathComponent("dead.lock").path, contents: nil)
        _ = store().load()
        XCTAssertEqual(onDisk, [])
    }
}

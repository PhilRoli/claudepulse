import Darwin
import Foundation

/// Serialises read-modify-write of one session's file across the hook processes and the app.
enum SessionLock {
    static func run<T>(directory: URL, sessionID: String, _ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = open(lockURL(directory, sessionID).path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(fd) }
        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    static func remove(directory: URL, sessionID: String) {
        try? FileManager.default.removeItem(at: lockURL(directory, sessionID))
    }

    private static func lockURL(_ directory: URL, _ sessionID: String) -> URL {
        directory.appendingPathComponent("\(sessionID).lock")
    }
}

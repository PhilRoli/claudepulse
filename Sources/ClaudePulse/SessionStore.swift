import Foundation

final class SessionStore {
    static let staleAfter: TimeInterval = 12 * 3600

    var onChange: (() -> Void)?

    private let directory: URL
    private let isAlive: (Int32) -> Bool
    private let now: () -> Date
    private var source: DispatchSourceFileSystemObject?
    private var timer: Timer?

    init(directory: URL, isAlive: @escaping (Int32) -> Bool = { kill($0, 0) == 0 }, now: @escaping () -> Date = Date.init) {
        self.directory = directory
        self.isAlive = isAlive
        self.now = now
    }

    static func encode(_ record: SessionRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(record)
    }

    static func decode(_ data: Data?) -> SessionRecord? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionRecord.self, from: data)
    }

    /// Live sessions, oldest update first. Corrupt files are skipped; dead or stale ones are deleted.
    func load() -> [SessionRecord] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var records: [SessionRecord] = []
        for url in urls where url.pathExtension == "json" {
            guard let record = Self.decode(try? Data(contentsOf: url)) else { continue }
            if isStale(record) {
                try? FileManager.default.removeItem(at: url)
            } else {
                records.append(record)
            }
        }
        return records.sorted { $0.updatedAt < $1.updatedAt }
    }

    func markSeen(sessionID: String) {
        let url = directory.appendingPathComponent("\(sessionID).json")
        guard var record = Self.decode(try? Data(contentsOf: url)), record.state == .finished, !record.seen else { return }
        record.seen = true
        try? Self.encode(record).write(to: url, options: .atomic)
    }

    func startWatching() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = open(directory.path, O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
            source.setEventHandler { [weak self] in self?.onChange?() }
            source.setCancelHandler { close(fd) }
            source.resume()
            self.source = source
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.onChange?() }
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        timer?.invalidate()
        timer = nil
    }

    private func isStale(_ record: SessionRecord) -> Bool {
        if let pid = record.pid { return !isAlive(pid) }
        return now().timeIntervalSince(record.updatedAt) > Self.staleAfter
    }
}

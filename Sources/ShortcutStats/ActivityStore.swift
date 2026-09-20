import Foundation
import SQLite3

struct MetricDelta { let metric: String; let value: Double }
struct ActivitySlice { let start: Date; let end: Date; let appID: String; let appName: String }
struct HourMetric: Identifiable {
    var id: String { "\(hour.timeIntervalSince1970)|\(day)|\(appID)|\(metric)" }
    let hour: Date
    let day: String
    let appID: String
    let appName: String
    let metric: String
    var value: Double
}

// New hourly aggregates are separate from the legacy daily shortcut file.
// No event sequence, input text, pointer location or inferred historical hours.
final class ActivityStore {
    private var db: OpaquePointer?
    private var cachedBucket: (interval: DateInterval, day: String, calendar: Calendar)?
    private var pending: [String: HourMetric] = [:]
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw failure() }
        do {
            try execute("PRAGMA journal_mode=WAL; PRAGMA busy_timeout=1500;")
            try execute("CREATE TABLE IF NOT EXISTS metrics(hour REAL NOT NULL, day TEXT NOT NULL, app TEXT NOT NULL, name TEXT NOT NULL, metric TEXT NOT NULL, value REAL NOT NULL, PRIMARY KEY(hour,day,app,metric));")
            try execute("CREATE INDEX IF NOT EXISTS metrics_day ON metrics(day)")
        } catch { sqlite3_close(db); db = nil; throw error }
    }
    deinit { sqlite3_close(db) }
    private func failure() -> NSError {
        NSError(domain: "ActivityStore", code: Int(sqlite3_errcode(db)), userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))])
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    func add(_ delta: MetricDelta, at date: Date, appID: String, appName: String, calendar: Calendar = .current) {
        guard delta.value.isFinite, delta.value > 0 else { return }
        if cachedBucket == nil || cachedBucket!.calendar != calendar || date < cachedBucket!.interval.start || date >= cachedBucket!.interval.end {
            guard let interval = calendar.dateInterval(of: .hour, for: date) else { return }
            cachedBucket = (interval, Statistics.dayString(date, calendar: calendar), calendar)
        }
        guard let bucket = cachedBucket else { return }
        let row = HourMetric(hour: bucket.interval.start, day: bucket.day, appID: appID, appName: appName, metric: delta.metric, value: delta.value)
        let key = row.id + "|" + row.day
        if pending[key] != nil { pending[key]!.value += delta.value } else { pending[key] = row }
    }
    func add(_ slice: ActivitySlice, calendar: Calendar = .current) {
        var start = slice.start
        while start < slice.end {
            guard let interval = calendar.dateInterval(of: .hour, for: start) else { break }
            let end = min(interval.end, slice.end)
            guard end > start else { break }
            add(MetricDelta(metric: "active.seconds", value: end.timeIntervalSince(start)), at: start,
                appID: slice.appID, appName: slice.appName, calendar: calendar)
            start = end
        }
    }
    func flush() throws {
        guard !pending.isEmpty else { return }
        try execute("BEGIN IMMEDIATE")
        do {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "INSERT INTO metrics VALUES(?,?,?,?,?,?) ON CONFLICT(hour,day,app,metric) DO UPDATE SET value=value+excluded.value,name=excluded.name", -1, &statement, nil) == SQLITE_OK else { throw failure() }
            defer { sqlite3_finalize(statement) }
            for row in pending.values {
                sqlite3_reset(statement)
                sqlite3_bind_double(statement, 1, row.hour.timeIntervalSince1970)
                for (index, value) in [row.day, row.appID, row.appName, row.metric].enumerated() {
                    sqlite3_bind_text(statement, Int32(index + 2), value, -1, transient)
                }
                sqlite3_bind_double(statement, 6, row.value)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
            }
            try execute("COMMIT")
            pending.removeAll()
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func rows(from: String, through: String, appID: String) throws -> [HourMetric] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT hour,day,app,name,metric,value FROM metrics WHERE day>=? AND day<=? AND (?='' OR app=?) ORDER BY hour", -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        for (index, value) in [from, through, appID, appID].enumerated() { sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient) }
        var result: [HourMetric] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            func string(_ index: Int32) -> String { String(cString: sqlite3_column_text(statement, index)) }
            result.append(HourMetric(hour: Date(timeIntervalSince1970: sqlite3_column_double(statement, 0)), day: string(1), appID: string(2), appName: string(3), metric: string(4), value: sqlite3_column_double(statement, 5)))
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw failure() }
        var merged = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        for row in pending.values where row.day >= from && row.day <= through && (appID.isEmpty || row.appID == appID) {
            if merged[row.id] != nil { merged[row.id]!.value += row.value } else { merged[row.id] = row }
        }
        return merged.values.sorted { $0.hour < $1.hour }
    }
}

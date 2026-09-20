import Foundation

struct StatisticsBackup: Codable {
    let format: String
    let version: Int
    let createdAt: Date
    let records: [UsageRecord]
    let hours: [HourMetric]
    let interruptions: [TrackingGap]

    init(records: [UsageRecord], hours: [HourMetric], interruptions: [TrackingGap], createdAt: Date = Date()) {
        format = "ShortcutStatsBackup"
        version = 1
        self.createdAt = createdAt
        self.records = records
        self.hours = hours
        self.interruptions = interruptions
    }
}

enum BackupCodec {
    static func invalid(_ message: String) -> NSError {
        NSError(domain: "ShortcutStats.Backup", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    static func validate(_ backup: StatisticsBackup) throws {
        guard backup.format == "ShortcutStatsBackup", backup.version == 1 else { throw invalid("不支持的备份格式或版本") }
        func date(_ value: Date) -> Bool { value.timeIntervalSince1970.isFinite && (0...253402214400).contains(value.timeIntervalSince1970) }
        func text(_ value: String, empty: Bool = false) -> Bool {
            (empty || !value.isEmpty) && value.utf8.count <= 4096 && !value.unicodeScalars.contains { $0.value < 32 }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        func day(_ value: String) -> Bool {
            guard value.count == 10, let parsed = formatter.date(from: value) else { return false }
            return formatter.string(from: parsed) == value
        }
        guard date(backup.createdAt) else { throw invalid("备份时间无效") }
        var keys = Set<[String]>()
        var total = 0
        for row in backup.records {
            let (sum, overflow) = total.addingReportingOverflow(row.count)
            guard day(row.day), text(row.appID), !row.appID.contains("|"), text(row.appName, empty: true), text(row.shortcut), row.count >= 0, !overflow, sum <= Int.max / 2,
                  keys.insert([row.day, row.appID, row.shortcut]).inserted else { throw invalid("快捷键记录无效、重复或次数过大") }
            total = sum
            for (key, value) in row.modifierCounts ?? [:] {
                guard ["L⌘", "R⌘", "?⌘", "L⌥", "R⌥", "?⌥", "L⌃", "R⌃", "?⌃", "L⇧", "R⇧", "?⇧"].contains(key),
                      value >= 0, value <= row.count else { throw invalid("修饰键次数无效") }
            }
        }
        var hourIDs = Set<String>()
        var metricTotal = 0.0
        for row in backup.hours {
            metricTotal += row.value
            guard date(row.hour), day(row.day), text(row.appID), !row.appID.contains("|"), text(row.appName, empty: true), text(row.metric), !row.metric.contains("|"), row.value.isFinite, row.value >= 0,
                  metricTotal.isFinite, metricTotal <= Double(Int.max / 2),
                  hourIDs.insert(row.id).inserted else { throw invalid("小时记录无效、重复或数值过大") }
        }
        var gapIDs = Set<UUID>()
        for gap in backup.interruptions {
            guard date(gap.start), gap.end.map({ date($0) && $0 >= gap.start }) ?? true,
                  gap.reason != .recording, gapIDs.insert(gap.id).inserted else { throw invalid("中断记录无效或重复") }
        }
    }
    static func encode(_ backup: StatisticsBackup) throws -> Data {
        try validate(backup)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(backup)
        guard data.count <= 256 * 1024 * 1024 else { throw invalid("备份超过 256 MB 限制") }
        return data
    }
    static func decode(_ data: Data) throws -> StatisticsBackup {
        guard data.count <= 256 * 1024 * 1024 else { throw invalid("备份超过 256 MB 限制") }
        let backup = try JSONDecoder().decode(StatisticsBackup.self, from: data)
        try validate(backup)
        return backup
    }
}

/// A durable rollback journal coordinates the SQLite transaction and two JSON files.
/// A crash at any intermediate point rolls back before Monitor loads or records data.
struct BackupRestore {
    let directory: URL
    var journal: URL { directory.appendingPathComponent("restore-pending.json") }
    func apply(_ backup: StatisticsBackup, store: ActivityStore) throws {
        try store.replace(with: backup.hours)
        try JSONEncoder().encode(backup.records).write(to: directory.appendingPathComponent("statistics.json"), options: .atomic)
        try JSONEncoder().encode(backup.interruptions).write(to: directory.appendingPathComponent("interruptions.json"), options: .atomic)
    }
    func recoverIfNeeded(store: ActivityStore) throws {
        guard FileManager.default.fileExists(atPath: journal.path) else { return }
        let original = try BackupCodec.decode(Data(contentsOf: journal))
        try apply(original, store: store)
        try FileManager.default.removeItem(at: journal)
    }
    @discardableResult
    func restore(_ replacement: StatisticsBackup, original: StatisticsBackup, store: ActivityStore,
                 afterApply: () throws -> Void = {}) throws -> URL {
        let originalData = try BackupCodec.encode(original)
        try BackupCodec.validate(replacement)
        guard !FileManager.default.fileExists(atPath: journal.path) else { throw BackupCodec.invalid("仍有未完成恢复，请重启应用后再试") }
        let folder = directory.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safety = folder.appendingPathComponent("Before-Restore-\(UUID().uuidString).json")
        try originalData.write(to: safety, options: .atomic)
        try originalData.write(to: journal, options: .atomic)
        do {
            try apply(replacement, store: store)
            try afterApply()
            try FileManager.default.removeItem(at: journal)
            return safety
        } catch {
            let cause = error
            do { try recoverIfNeeded(store: store) }
            catch { throw BackupCodec.invalid("恢复和回滚均未完成，已保留恢复日志；请勿启动其他副本。原备份：\(safety.path)。\(error.localizedDescription)") }
            throw cause
        }
    }
}

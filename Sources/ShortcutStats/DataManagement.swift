import Foundation

enum DataRetention: Int, CaseIterable, Identifiable {
    case forever = 0
    case days30 = 30
    case days90 = 90
    case days180 = 180
    case days365 = 365

    var id: Int { rawValue }
    var title: String { rawValue == 0 ? "永久保留" : "保留最近 \(rawValue) 天" }

    static func validated(_ value: Int) -> DataRetention {
        DataRetention(rawValue: value) ?? .forever
    }
}

enum DataRemovalKind {
    case dateRange(from: String, through: String)
    case shortcuts
    case hourly
}

struct ManagedFileUsage: Identifiable, Equatable {
    let id: String
    let title: String
    let bytes: Int64
}

struct DataManagementReport: Equatable {
    let files: [ManagedFileUsage]
    let shortcutRows: Int
    let shortcutUses: Int
    let hourlyRows: Int
    let ordinaryKeyPresses: Double
    let mouseClicks: Double
    let activeSeconds: Double
    let downloadBytes: Double
    let uploadBytes: Double
    let interruptionRows: Int
    let firstDay: String?
    let lastDay: String?

    var totalBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
}

enum DataManagement {
    static let retentionDefaultsKey = "data.retentionDays"
    static let retentionLastCheckDefaultsKey = "data.retentionLastCheck"

    static func report(directory: URL, backup: StatisticsBackup,
                       fileManager: FileManager = .default,
                       calendar: Calendar = .current) -> DataManagementReport {
        let fixedFiles = [
            ("statistics.json", "快捷键数据"),
            ("interruptions.json", "中断记录"),
            ("activity.sqlite", "扩展小时数据"),
            ("activity.sqlite-wal", "扩展数据日志"),
            ("activity.sqlite-shm", "扩展数据共享内存"),
            ("restore-pending.json", "恢复保护日志")
        ]
        var files = fixedFiles.compactMap { name, title -> ManagedFileUsage? in
            let size = fileSize(directory.appendingPathComponent(name), fileManager: fileManager)
            return size > 0 ? ManagedFileUsage(id: name, title: title, bytes: size) : nil
        }
        let backups = directory.appendingPathComponent("Backups", isDirectory: true)
        let backupBytes = recursiveSize(backups, fileManager: fileManager)
        if backupBytes > 0 {
            files.append(ManagedFileUsage(id: "Backups", title: "安全备份", bytes: backupBytes))
        }

        var days = backup.records.map(\.day) + backup.hours.map(\.day)
        days += backup.interruptions.flatMap { gap -> [String] in
            var values = [Statistics.dayString(gap.start, calendar: calendar)]
            if let end = gap.end { values.append(Statistics.dayString(end, calendar: calendar)) }
            return values
        }
        let shortcutUses = backup.records.reduce(into: 0) { total, row in
            let (value, overflow) = total.addingReportingOverflow(row.count)
            total = overflow ? Int.max : value
        }
        func metricTotal(where include: (String) -> Bool) -> Double {
            backup.hours.filter { include($0.metric) && $0.value.isFinite && $0.value > 0 }
                .reduce(0) { $0 + $1.value }
        }
        return DataManagementReport(
            files: files, shortcutRows: backup.records.count, shortcutUses: shortcutUses,
            hourlyRows: backup.hours.count,
            ordinaryKeyPresses: metricTotal { $0.hasPrefix("key:") },
            mouseClicks: metricTotal { ["mouse.left", "mouse.right", "mouse.other"].contains($0) },
            activeSeconds: metricTotal { $0 == "active.seconds" },
            downloadBytes: metricTotal { $0 == "network.download.bytes" },
            uploadBytes: metricTotal { $0 == "network.upload.bytes" },
            interruptionRows: backup.interruptions.count,
            firstDay: days.min(), lastDay: days.max()
        )
    }

    static func removing(_ kind: DataRemovalKind, from backup: StatisticsBackup,
                         calendar: Calendar = .current) throws -> StatisticsBackup {
        let replacement: StatisticsBackup
        switch kind {
        case let .dateRange(from, through):
            guard from <= through,
                  let interval = inclusiveInterval(from: from, through: through, calendar: calendar) else {
                throw BackupCodec.invalid("删除日期范围无效")
            }
            replacement = StatisticsBackup(
                records: backup.records.filter { $0.day < from || $0.day > through },
                hours: backup.hours.filter { $0.day < from || $0.day > through },
                interruptions: backup.interruptions.filter { !overlaps($0, interval: interval) }
            )
        case .shortcuts:
            replacement = StatisticsBackup(records: [], hours: backup.hours, interruptions: backup.interruptions)
        case .hourly:
            replacement = StatisticsBackup(records: backup.records, hours: [], interruptions: backup.interruptions)
        }
        try BackupCodec.validate(replacement)
        return replacement
    }

    static func retentionReplacement(days: Int, now: Date = Date(), backup: StatisticsBackup,
                                     calendar: Calendar = .current) throws -> StatisticsBackup? {
        let retention = DataRetention.validated(days)
        guard retention != .forever,
              let firstKeptDay = calendar.date(byAdding: .day, value: -(retention.rawValue - 1),
                                               to: calendar.startOfDay(for: now)),
              let lastRemovedDay = calendar.date(byAdding: .day, value: -1, to: firstKeptDay) else { return nil }
        let through = Statistics.dayString(lastRemovedDay, calendar: calendar)
        let replacement = try removing(.dateRange(from: "0001-01-01", through: through), from: backup, calendar: calendar)
        guard replacement.records.count != backup.records.count
                || replacement.hours.count != backup.hours.count
                || replacement.interruptions.count != backup.interruptions.count else { return nil }
        return replacement
    }

    private static func inclusiveInterval(from: String, through: String, calendar: Calendar) -> DateInterval? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let start = formatter.date(from: from), let finalDay = formatter.date(from: through),
              formatter.string(from: start) == from, formatter.string(from: finalDay) == through,
              let end = calendar.date(byAdding: .day, value: 1, to: finalDay) else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func overlaps(_ gap: TrackingGap, interval: DateInterval) -> Bool {
        let end = gap.end ?? .distantFuture
        return gap.start < interval.end && end >= interval.start
    }

    private static func fileSize(_ url: URL, fileManager: FileManager) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let number = attributes[.size] as? NSNumber else { return 0 }
        return number.int64Value
    }

    private static func recursiveSize(_ directory: URL, fileManager: FileManager) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                                       options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            let (value, overflow) = total.addingReportingOverflow(Int64(values.fileSize ?? 0))
            total = overflow ? Int64.max : value
        }
        return total
    }
}

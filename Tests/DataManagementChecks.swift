import Foundation

func runDataManagementChecks() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let formatter = ISO8601DateFormatter()
    func date(_ value: String) -> Date { formatter.date(from: value)! }
    func record(_ day: String, _ count: Int = 1) -> UsageRecord {
        UsageRecord(day: day, appID: "test.app", appName: "Test", shortcut: "⌘C", count: count)
    }
    func hour(_ day: String, _ instant: String) -> HourMetric {
        HourMetric(hour: date(instant), day: day, appID: "test.app", appName: "Test", metric: "key:C", value: 1)
    }

    let outside = TrackingGap(start: date("2026-02-01T00:00:00Z"), end: date("2026-02-02T00:00:00Z"), reason: .paused)
    let inside = TrackingGap(start: date("2026-01-10T12:00:00Z"), end: date("2026-01-10T13:00:00Z"), reason: .paused)
    let crossing = TrackingGap(start: date("2026-01-31T23:00:00Z"), end: date("2026-02-01T01:00:00Z"), reason: .permission)
    let source = StatisticsBackup(
        records: [record("2026-01-10", 4), record("2026-02-01", 3)],
        hours: [hour("2026-01-10", "2026-01-10T12:00:00Z"), hour("2026-02-01", "2026-02-01T12:00:00Z")],
        interruptions: [outside, inside, crossing]
    )

    do {
        let ranged = try DataManagement.removing(.dateRange(from: "2026-01-01", through: "2026-01-31"), from: source, calendar: calendar)
        check(ranged.records.map(\.day) == ["2026-02-01"] && ranged.hours.map(\.day) == ["2026-02-01"],
              "按日期删除快捷键与扩展小时数据且包含两端")
        check(ranged.interruptions.map(\.id) == [outside.id], "按日期删除范围内及跨越边界的中断记录")
        check((try? DataManagement.removing(.dateRange(from: "2026-02-01", through: "2026-01-01"), from: source, calendar: calendar)) == nil,
              "拒绝倒置删除日期范围")

        let shortcuts = try DataManagement.removing(.shortcuts, from: source, calendar: calendar)
        check(shortcuts.records.isEmpty && shortcuts.hours.count == 2 && shortcuts.interruptions.count == 3,
              "单独清空快捷键保留扩展数据与中断")
        let hourly = try DataManagement.removing(.hourly, from: source, calendar: calendar)
        check(hourly.hours.isEmpty && hourly.records.count == 2 && hourly.interruptions.count == 3,
              "单独清空扩展小时数据保留快捷键与中断")

        let retentionSource = StatisticsBackup(
            records: [record("2026-03-11"), record("2026-03-12"), record("2026-04-10")],
            hours: [hour("2026-03-11", "2026-03-11T12:00:00Z"), hour("2026-03-12", "2026-03-12T12:00:00Z")],
            interruptions: [TrackingGap(start: date("2026-03-11T23:00:00Z"), end: date("2026-03-12T01:00:00Z"), reason: .paused)]
        )
        let retained = try DataManagement.retentionReplacement(days: 30, now: date("2026-04-10T12:00:00Z"), backup: retentionSource, calendar: calendar)
        check(retained?.records.map(\.day) == ["2026-03-12", "2026-04-10"] && retained?.hours.map(\.day) == ["2026-03-12"],
              "30 天保留含今天并按日历边界清理")
        check(retained?.interruptions.isEmpty == true, "保留期限清理与过期范围有交集的中断")
        let permanent = try DataManagement.retentionReplacement(days: 0, now: date("2026-04-10T12:00:00Z"), backup: source, calendar: calendar)
        check(permanent == nil, "永久保留不删除数据")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ShortcutStats-DataManagement-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Backups"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10).write(to: folder.appendingPathComponent("statistics.json"))
        try Data(repeating: 2, count: 20).write(to: folder.appendingPathComponent("activity.sqlite"))
        try Data(repeating: 3, count: 30).write(to: folder.appendingPathComponent("activity.sqlite-wal"))
        try Data(repeating: 4, count: 40).write(to: folder.appendingPathComponent("activity.sqlite-shm"))
        try Data(repeating: 5, count: 50).write(to: folder.appendingPathComponent("Backups/test.json"))
        let report = DataManagement.report(directory: folder, backup: source, calendar: calendar)
        check(report.totalBytes == 150 && report.files.contains { $0.id == "Backups" && $0.bytes == 50 },
              "存储占用包含 SQLite WAL/SHM 与 Backups")
        check(report.shortcutRows == 2 && report.shortcutUses == 7 && report.hourlyRows == 2 && report.interruptionRows == 3,
              "数据概况分别统计各类记录与快捷键次数")
        check(report.ordinaryKeyPresses == 2 && report.mouseClicks == 0 && report.activeSeconds == 0,
              "数据概况汇总扩展统计中的主键、鼠标与活跃时长")
        check(report.firstDay == "2026-01-10" && report.lastDay == "2026-02-02", "数据概况日期范围包含中断起止日")
    } catch {
        check(false, "数据管理隔离检查失败：\(error)")
    }
}

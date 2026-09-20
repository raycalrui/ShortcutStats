import Foundation

func runBackupChecks() {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ShortcutStats-Backup-Test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let record = UsageRecord(day: "2027-01-15", appID: "test.app", appName: "Test", shortcut: "⌘C", count: 4, modifierCounts: ["L⌘": 4])
    let hour = HourMetric(hour: date, day: "2027-01-15", appID: "test.app", appName: "Test", metric: "key:C", value: 4)
    let original = StatisticsBackup(records: [record], hours: [hour], interruptions: [TrackingGap(start: date, end: date, reason: .paused)])
    func rejects(_ value: StatisticsBackup) -> Bool { (try? BackupCodec.encode(value)) == nil }
    do {
        let encoded = try BackupCodec.encode(original)
        let decoded = try BackupCodec.decode(encoded)
        check(decoded.records.first?.modifierCounts?["L⌘"] == 4 && decoded.hours.first?.value == 4 && decoded.interruptions.count == 1, "完整备份往返保留三类数据")
        check(rejects(StatisticsBackup(records: [record, record], hours: [], interruptions: [])), "备份拒绝重复快捷键")
        check(rejects(StatisticsBackup(records: [], hours: [hour, hour], interruptions: [])), "备份拒绝重复小时指标")
        var excessive = record; excessive.count = Int.max
        check(rejects(StatisticsBackup(records: [excessive], hours: [], interruptions: [])), "备份拒绝没有后续增长余量的极大次数")
        var negative = record; negative.count = -1
        check(rejects(StatisticsBackup(records: [negative], hours: [], interruptions: [])), "备份拒绝负次数")
        var nan = hour; nan.value = .nan
        check(rejects(StatisticsBackup(records: [], hours: [nan], interruptions: [])), "备份拒绝非有限值")
        let future = String(decoding: encoded, as: UTF8.self).replacingOccurrences(of: "\"version\":1", with: "\"version\":99")
        check((try? BackupCodec.decode(Data(future.utf8))) == nil, "备份拒绝未知版本")
        let store = try ActivityStore(url: folder.appendingPathComponent("activity.sqlite"))
        try store.replace(with: original.hours)
        store.add(MetricDelta(metric: "mouse.left", value: 2), at: date, appID: "test.app", appName: "Test")
        let pendingRows = try store.snapshot()
        check(pendingRows.contains { $0.metric == "mouse.left" && $0.value == 2 }, "完整快照包含未落盘 pending 数据")
        let restore = BackupRestore(directory: folder)
        let replacement = StatisticsBackup(records: [], hours: [], interruptions: [])
        let safety = try restore.restore(replacement, original: original, store: store)
        let emptyRows = try store.snapshot()
        check(emptyRows.isEmpty && FileManager.default.fileExists(atPath: safety.path), "恢复替换而非累加且先保留旧备份")
        do {
            try restore.restore(replacement, original: original, store: store) { throw BackupCodec.invalid("injected failure") }
            check(false, "恢复注入故障必须抛错")
        } catch { check(true, "恢复注入故障明确抛错") }
        let rolledBack = try store.snapshot()
        let rolledRecords = try JSONDecoder().decode([UsageRecord].self, from: Data(contentsOf: folder.appendingPathComponent("statistics.json")))
        check(rolledBack.first?.value == 4 && rolledRecords.first?.count == 4 && !FileManager.default.fileExists(atPath: restore.journal.path), "跨文件恢复失败回滚 SQLite 和 JSON")
        try BackupCodec.encode(original).write(to: restore.journal, options: .atomic)
        try store.replace(with: [])
        try restore.recoverIfNeeded(store: store)
        let recoveredRows = try store.snapshot()
        check(recoveredRows.first?.value == 4 && !FileManager.default.fileExists(atPath: restore.journal.path), "启动恢复日志修复模拟中断操作")
        let collision = HourMetric(hour: date, day: "2027-01-15", appID: "test|app", appName: "Test", metric: "key:C", value: 4)
        check(rejects(StatisticsBackup(records: [], hours: [collision], interruptions: [])), "备份拒绝会破坏小时记录标识的分隔符")
        let brokenFolder = folder.appendingPathComponent("broken")
        let brokenStore = try ActivityStore(url: brokenFolder.appendingPathComponent("activity.sqlite"))
        let brokenRestore = BackupRestore(directory: brokenFolder)
        let blockedJSON = brokenFolder.appendingPathComponent("interruptions.json")
        try FileManager.default.createDirectory(at: blockedJSON, withIntermediateDirectories: true)
        // Nonempty directory guarantees JSON's atomic rename cannot replace it.
        try Data([1]).write(to: blockedJSON.appendingPathComponent("blocker"))
        do {
            try brokenRestore.restore(replacement, original: original, store: brokenStore)
            check(false, "真实 JSON 写入故障必须报告失败")
        } catch {
            check(FileManager.default.fileExists(atPath: brokenRestore.journal.path), "跨文件中途失败且回滚失败保留恢复日志")
        }
        let preserved = try BackupCodec.decode(Data(contentsOf: brokenRestore.journal))
        check(preserved.records.first?.count == 4 && preserved.hours.first?.value == 4, "回滚失败日志保留完整恢复前数据")
        try FileManager.default.removeItem(at: blockedJSON)
        try brokenRestore.recoverIfNeeded(store: brokenStore)
        let repairedRows = try brokenStore.snapshot()
        let repairedGaps = try JSONDecoder().decode([TrackingGap].self, from: Data(contentsOf: blockedJSON))
        check(repairedRows.first?.value == 4 && repairedGaps.count == 1 && !FileManager.default.fileExists(atPath: brokenRestore.journal.path), "排除真实文件故障后重启恢复三类数据")
        let before = try store.snapshot()
        do { try store.replace(with: [hour, hour]); check(false, "SQLite 重复主键必须失败") }
        catch { let after = try store.snapshot(); check(after.count == before.count, "SQLite 替换失败保留原事务数据") }
    } catch { check(false, "备份隔离检查失败：\(error)") }
}

import Foundation
import CoreGraphics

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    print("PASS: \(message)")
}

let event = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true)!
event.flags = []
check(Monitor.shortcut(for: event) == nil, "普通打字不计数")
event.flags = [.maskShift]
check(Monitor.shortcut(for: event) == nil, "仅 Shift 不计数")
event.flags = [.maskCommand]
check(Monitor.shortcut(for: event) == "⌘C", "识别 Command C")
event.flags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
check(Monitor.shortcut(for: event) == "⌃⌥⇧⌘C", "多修饰键归一化")
event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
check(Monitor.shortcut(for: event) == nil, "忽略长按重复")
event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
event.type = .keyUp
check(Monitor.shortcut(for: event) == nil, "抬键不重复计数")

let rows = [
    UsageRecord(day: "2026-09-16", appID: "a", appName: "A", shortcut: "⌘C", count: 4),
    UsageRecord(day: "2026-09-17", appID: "a", appName: "A", shortcut: "⌘C", count: 3),
    UsageRecord(day: "2026-09-17", appID: "b", appName: "B", shortcut: "⌘V", count: 9)
]
check(Statistics.rankings(rows, since: "", appID: "").map(\.count) == [9, 7], "跨日期合并与降序排名")
check(Statistics.rankings(rows, since: "2026-09-17", appID: "a").map(\.count) == [3], "日期和应用联合筛选")
check(Statistics.rankings(rows, since: "2026-09-18", appID: "").isEmpty, "无匹配记录")
let special = [UsageRecord(day: "2026-09-17", appID: "a", appName: "=SUM(1,2)\"", shortcut: "⌘C", count: 2)]
check(Statistics.csv(special).contains("\"'=SUM(1,2)\"\"\""), "CSV 转义及公式防护")
let decoded = try JSONDecoder().decode([UsageRecord].self, from: JSONEncoder().encode(rows))
check(decoded.map(\.count) == rows.map(\.count), "统计数据序列化往返")


// Environment changes must never override a manual pause.
for sleeping in [false, true] {
    for authorized in [false, true] {
        for secure in [false, true] {
            check(TrackingHealth.blockedState(wantsTracking: false, dataValid: true, sleeping: sleeping,
                  authorized: authorized, secureInput: secure) == .paused, "手动暂停优先于环境恢复")
        }
    }
}
check(TrackingHealth.blockedState(wantsTracking: true, dataValid: true, sleeping: false, authorized: false, secureInput: false) == .permission, "撤销权限进入等待")
check(TrackingHealth.blockedState(wantsTracking: true, dataValid: true, sleeping: false, authorized: true, secureInput: false) == nil, "权限恢复允许重建")
check(TrackingHealth.blockedState(wantsTracking: true, dataValid: true, sleeping: true, authorized: true, secureInput: false) == .sleeping, "睡眠阻止采集")
check(TrackingHealth.blockedState(wantsTracking: true, dataValid: true, sleeping: false, authorized: true, secureInput: true) == .secureInput, "安全输入阻止采集")
check(TrackingHealth.blockedState(wantsTracking: true, dataValid: false, sleeping: false, authorized: true, secureInput: false) == .dataError, "损坏历史禁止恢复")
let t = Date(timeIntervalSince1970: 1000)
var gaps = GapHistory()
gaps.transition(to: .permission, at: t)
gaps.transition(to: .permission, at: t.addingTimeInterval(2))
check(gaps.entries.count == 1, "重复健康检查不重复记录中断")
gaps.transition(to: .recording, at: t.addingTimeInterval(5))
check(gaps.entries[0].end == t.addingTimeInterval(5), "恢复时关闭中断时段")
gaps.transition(to: .sleeping, at: t.addingTimeInterval(8))
gaps.transition(to: .paused, at: t.addingTimeInterval(10))
check(gaps.entries.count == 3 && gaps.entries[1].end == t.addingTimeInterval(10), "原因变化切分时段")
gaps.finish(at: t.addingTimeInterval(15))
check(gaps.entries.last?.end == t.addingTimeInterval(15), "正常退出结束当前时段")
var restored = GapHistory()
restored.entries = try JSONDecoder().decode([TrackingGap].self, from: JSONEncoder().encode(gaps.entries))
restored.transition(to: .permission, at: t.addingTimeInterval(20))
check(restored.entries.count == 4, "重新启动保留历史并建立新时段")

let filtered = Statistics.filtered(rows, from: "2026-09-17", through: "2026-09-17", appID: "a")
check(filtered.map(\.count) == [3], "自定义单日包含起止边界并匹配应用")
check(Statistics.filtered(rows, from: "2026-09-18", through: "2026-09-17", appID: "").isEmpty, "倒置日期不产生结果")
check(Statistics.filtered(rows, from: "2026-09-16", through: "2026-09-16", appID: "").map(\.count) == [4], "结束日期排除后续记录")
check(Statistics.filtered(rows, from: "", through: "9999", appID: "", search: "c").map(\.count) == [4, 3], "搜索忽略大小写")
check(Statistics.filtered(rows, from: "", through: "9999", appID: "", hidden: ["⌘C"]).map(\.count) == [9], "隐藏组合键不改变其他计数")
check(Statistics.csv(filtered).contains("2026-09-17") && !Statistics.csv(filtered).contains("2026-09-16"), "导出遵循同一日期筛选")
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!
let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
let daily = Statistics.daily([], from: start, through: end, calendar: calendar)
check(daily.map(\.day) == ["2026-03-07", "2026-03-08", "2026-03-09", "2026-03-10"], "夏令时切换按日历补齐日期")
check(daily.allSatisfy { $0.count == 0 }, "无记录日期显示零而非缺失日期")
let monthStart = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
let monthEnd = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
check(Statistics.daily([], from: monthStart, through: monthEnd, calendar: calendar).count == 2, "跨月范围包含两端")
let keyRows = rows + [UsageRecord(day: "2026-09-17", appID: "a", appName: "A", shortcut: "⌃⌥⇧⌘C", count: 2), UsageRecord(day: "2026-09-17", appID: "a", appName: "A", shortcut: "⌘Num +", count: 1)]
check(Statistics.keyTotals(keyRows)["C"] == 9, "热力图合并主键的不同修饰组合")
check(Statistics.keyTotals(keyRows)["Num +"] == 1 && Statistics.keyTotals(keyRows)["?⌘"] == 19, "热力图保留小键盘标识且累计 Command 参与次数")
check(Statistics.rankings(rows, since: "", appID: "").reduce(0) { $0 + $1.count } == 16, "展示过滤不修改原始记录")

check(Statistics.keyTotals(keyRows)["?⇧"] == 2 && Statistics.keyTotals(keyRows)["?⌥"] == 2 && Statistics.keyTotals(keyRows)["?⌃"] == 2, "多修饰组合每个修饰键各累计一次")
check(Statistics.keys(in: "⇧⌘A") == Set(["⇧", "⌘", "A"]), "点击修饰键明细匹配完整组合")
check(Statistics.keyTotals(keyRows)["fn"] == nil, "不推算未记录的 Fn 使用")

let commandFlag: UInt64 = 1 << 20
check(Statistics.modifierCounts(flags: commandFlag | 8) == ["L⌘": 1], "左 Command")
check(Statistics.modifierCounts(flags: commandFlag | 16) == ["R⌘": 1], "右 Command")
check(Statistics.modifierCounts(flags: commandFlag | 24) == ["L⌘": 1, "R⌘": 1], "同时按左右各计一次")
check(Statistics.modifierCounts(flags: commandFlag) == ["?⌘": 1], "缺少左右标志不沿用上次状态")
check(Statistics.modifierCounts(flags: 24).isEmpty, "没有组合标志忽略残余位")
check(Statistics.modifierCounts(flags: (1 << 18) | 0x2000) == ["R⌃": 1], "右 Control 独立位")
check(Statistics.modifierCounts(flags: (1 << 19) | (1 << 17) | 0x20 | 0x04) == ["L⌥": 1, "R⇧": 1], "多种修饰键左右独立")
let legacyJSON = Data(#"{"day":"2026-09-20","appID":"test","appName":"Test","shortcut":"⌘C","count":3}"#.utf8)
var sided = try JSONDecoder().decode(UsageRecord.self, from: legacyJSON)
check(sided.resolvedModifierCounts == ["?⌘": 3], "旧格式读取为未知")
sided.addOccurrence(modifiers: ["L⌘": 1])
sided.addOccurrence(modifiers: ["R⌘": 1])
let roundTrip = try JSONDecoder().decode(UsageRecord.self, from: JSONEncoder().encode(sided))
check(roundTrip.count == 5 && roundTrip.modifierCounts == ["?⌘": 3, "L⌘": 1, "R⌘": 1], "新旧聚合与保存恢复")
check(Statistics.records([roundTrip], forKey: "L⌘").first?.count == 1, "侧键明细仅使用该侧次数")
check(Statistics.keyTotals([roundTrip])["C"] == 5, "主键保留全部历史")
check(Statistics.rankings([roundTrip], since: "", appID: "").first?.count == 5, "排行榜继续合并左右")

for (code, name) in Monitor.keyNames where name.hasPrefix("F") && Int(name.dropFirst()) != nil {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
    event.flags = []
    check(Monitor.shortcut(for: event) == name, "单独功能键 \(name)")
    event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
    check(Monitor.shortcut(for: event) == nil, "功能键长按不重复 \(name)")
}
check(Monitor.mediaShortcut(subtype: 8, data: 0x0a00) == "音量增加", "媒体按下")
check(Monitor.mediaShortcut(subtype: 8, data: 0x0b00) == nil, "媒体抬起不计数")
check(Monitor.mediaShortcut(subtype: 8, data: 0x0a01) == nil, "媒体长按不重复")
check(Monitor.mediaShortcut(subtype: 7, data: 0x0a00) == nil, "忽略其他系统事件")
check(Monitor.mediaShortcut(subtype: 8, data: (16 << 16) | 0x0a00) == "播放/暂停", "播放键")
check(Monitor.mediaShortcut(subtype: 8, data: (99 << 16) | 0x0a00) == nil, "不猜测未知系统功能")

let selectionRows = [UsageRecord(day: "2026-09-20", appID: "test", appName: "Test", shortcut: "⇧⌘C", count: 10, modifierCounts: ["L⌘": 3, "R⌘": 7, "L⇧": 6, "R⇧": 4])]
let selectedRows = Statistics.heatmapRecords(selectionRows, modifier: "L⌘")
check(Statistics.keyTotals(selectedRows)["C"] == 3, "修饰键筛选主键只计实际该侧次数")
check(Statistics.keyTotals(selectedRows)["R⇧"] == nil, "不推算其他修饰键交集")
check(Statistics.rankings(selectedRows, since: "", appID: "").first?.count == 3, "多修饰组合明细使用筛选次数")
check(Statistics.heatmapRecords(selectionRows, modifier: "R⌘").first?.count == 7, "切换右侧筛选")
check(Statistics.heatmapRecords(selectionRows, modifier: nil).first?.count == 10, "取消恢复原始次数")
check(Statistics.heatmapRecords(selectionRows, modifier: "L⌥").isEmpty, "无匹配修饰键为空")
check(Statistics.heatmapRecords([sided], modifier: "L⌘").first?.count == 1, "未知历史不混入左右筛选")

let volumeRows = [UsageRecord(day: "2026-09-20", appID: "test", appName: "Test", shortcut: "音量增加", count: 4), UsageRecord(day: "2026-09-20", appID: "test", appName: "Test", shortcut: "F12", count: 2), UsageRecord(day: "2026-09-20", appID: "test", appName: "Test", shortcut: "音量降低", count: 3)]
check(Statistics.heatmapTotals(volumeRows)["F12"] == 6 && Statistics.heatmapTotals(volumeRows)["F11"] == 3, "音量事件合并到顶部音量键")
check(Statistics.heatmapTotals(volumeRows)["音量增加"] == nil, "音量不重复显示在额外键位")
check(Statistics.heatmapDetails(volumeRows, key: "F12").map(\.count) == [4, 2], "音量键明细保留操作与 F 键")
check(Statistics.heatmapTotals(Statistics.heatmapRecords(volumeRows, modifier: "L⌘")).isEmpty, "修饰键筛选不混入无修饰音量事件")

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

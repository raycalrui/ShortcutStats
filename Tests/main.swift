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

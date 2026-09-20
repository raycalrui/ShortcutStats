import SwiftUI
import Charts

struct ActivityDashboard: View {
    let rows: [HourMetric]
    @State private var metric = "shortcut"
    @AppStorage("metrics.keyboard") private var keyboard = false
    @AppStorage("metrics.mouse") private var mouse = false
    @AppStorage("metrics.active") private var active = false
    private func total(_ name: String) -> Double { rows.filter { $0.metric == name }.reduce(0) { $0 + $1.value } }
    private var keyRows: [UsageRecord] {
        rows.filter { $0.metric.hasPrefix("key:") }.map {
            UsageRecord(day: $0.day, appID: $0.appID, appName: $0.appName, shortcut: String($0.metric.dropFirst(4)), count: Int($0.value), modifierCounts: [:])
        }
    }
    private var hours: [(date: Date, value: Double)] {
        let selected = rows.filter { metric == "keys" ? $0.metric.hasPrefix("key:") : $0.metric == metric }
        return Dictionary(grouping: selected, by: \.hour).map { (date: $0.key, value: $0.value.reduce(0) { $0 + $1.value }) }.sorted { $0.date < $1.date }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("键鼠与活跃时长").font(.title2.bold())
                Toggle("统计全部主键（包括普通打字与快捷键主键）", isOn: $keyboard)
                Toggle("统计鼠标点击、滚动与移动", isOn: $mouse)
                Toggle("统计前台应用活跃时长", isOn: $active)
                Text("新增开关默认关闭。仅保存每小时汇总，不保存文字、按键顺序或鼠标轨迹。关闭保留历史；顶部暂停会停止全部采集。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    summary("主键按下", value: rows.filter { $0.metric.hasPrefix("key:") }.reduce(0) { $0 + $1.value }, enabled: keyboard)
                    summary("左键", value: total("mouse.left"), enabled: mouse)
                    summary("右键", value: total("mouse.right"), enabled: mouse)
                    summary("其他按钮", value: total("mouse.other"), enabled: mouse)
                }
                Text("移动：\(total("mouse.distance"), specifier: "%.0f") 事件单位 · 滚动：\(total("mouse.scroll.pixels"), specifier: "%.0f") 点 / \(total("mouse.scroll.lines"), specifier: "%.0f") 行")
                Text("移动不是实际物理距离；滚动分别累计水平和垂直绝对量，连续滚动包含惯性。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("应用活跃时长（分钟）").font(.headline)
                Text(active ? "60 秒无操作视为空闲；不累计锁屏、睡眠和暂停。采样间隔约 2 秒，恢复边界保守估算。" : "当前未开启时长采集；以下仅显示已有历史。")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Dictionary(grouping: rows.filter { $0.metric == "active.seconds" }, by: \.appID).map { (id: $0.key, name: $0.value.first?.appName ?? $0.key, value: $0.value.reduce(0) { $0 + $1.value }) }.sorted { $0.value > $1.value }, id: \.id) { item in
                    HStack { Text(item.name); Spacer(); Text(String(format: "%.1f", item.value / 60)) }
                }
                Divider()
                Text("每小时趋势").font(.headline)
                Picker("指标", selection: $metric) {
                    Text("快捷键次数").tag("shortcut")
                    Text("主键次数").tag("keys")
                    Text("左键次数").tag("mouse.left")
                    Text("右键次数").tag("mouse.right")
                    Text("活跃分钟").tag("active.seconds")
                }
                Text("仅包含新版开始采集后的小时汇总；旧每日记录不推算到小时。空白时段可能未采集，不代表没有使用。时间按当前时区显示。")
                    .font(.caption).foregroundStyle(.secondary)
                if hours.isEmpty { Text("当前范围暂无此指标的小时数据。").foregroundStyle(.secondary) }
                else {
                    Chart(hours, id: \.date) { point in
                        BarMark(x: .value("小时", point.date), y: .value("用量", metric == "active.seconds" ? point.value / 60 : point.value))
                    }.frame(height: 180)
                    ForEach(hours, id: \.date) { point in
                        HStack {
                            Text(point.date.formatted(.dateTime.month().day().hour()) + " · " + point.date.formatted(.dateTime.timeZone()))
                            Spacer()
                            Text(String(format: "%.1f", metric == "active.seconds" ? point.value / 60 : point.value))
                        }.font(.caption)
                    }
                }
                Divider()
                Text("全部主键热力图").font(.headline)
                Text("包含普通打字与快捷键主键，不记录字符内容；不单独累计修饰键按下。独立于原快捷键排行榜。")
                    .font(.caption).foregroundStyle(.secondary)
                KeyboardHeatmap(records: keyRows, ordinaryKeys: true).frame(height: 570)
            }.padding(.vertical, 8)
        }
    }
    private func summary(_ title: String, value: Double, enabled: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            Text(value.formatted(.number.precision(.fractionLength(0)))).font(.title2)
            if !enabled { Text("采集未开启").font(.caption2).foregroundStyle(.secondary) }
        }
    }
}

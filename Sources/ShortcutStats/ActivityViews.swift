import SwiftUI
import Charts

struct ActivityDashboard: View {
    let rows: [HourMetric]
    @State private var metric = "shortcut"
    @AppStorage("metrics.keyboard") private var keyboard = false
    @AppStorage("metrics.mouse") private var mouse = false
    @AppStorage("metrics.active") private var active = false
    private func total(_ name: String) -> Double { rows.filter { $0.metric == name }.reduce(0) { $0 + $1.value } }
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


/// Both views receive the same date/app-filtered range as the other statistics tabs.
struct AppUsageRankingView: View {
    let rows: [HourMetric]
    @AppStorage("metrics.active") private var active = false

    private var summary: ActivitySummary { ActivitySummary(rows: rows, records: []) }

    var body: some View {
        let data = summary
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("应用使用时长").font(.title2.bold())
                    Spacer()
                    Text("合计 \(ActivityDisplay.duration(data.activeSeconds))")
                        .font(.headline).monospacedDigit()
                }
                Text("按当前日期与应用范围统计前台活跃时长；占比以当前范围的总活跃时长为分母。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("统计前台应用活跃时长", isOn: $active)
                Text(active ? "采集已开启；60 秒无操作视为空闲，不累计锁屏、睡眠和暂停。" : "采集未开启；已有历史仍会显示，开启后开始累计新数据。")
                    .font(.caption).foregroundStyle(.secondary)
                if data.appRankings.isEmpty {
                    ContentUnavailableView(
                        "暂无应用时长数据",
                        systemImage: "clock",
                        description: Text(active ? "正常使用 Mac 后会出现数据，也可以调整上方日期与应用筛选。" : "开启活跃时长采集后，正常使用 Mac 即可开始累计。")
                    ).frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(data.appRankings.enumerated()), id: \.element.id) { index, app in
                            rankingRow(app, rank: index + 1)
                        }
                    }
                }
                Text("时长来自启用采集后的小时汇总，不推算旧数据或未运行时段。前台活跃时长不等于 App 打开时长。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }
    }

    private func rankingRow(_ app: AppActivityRanking, rank: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(rank)).font(.headline).foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing).padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(app.name).font(.headline).lineLimit(1).help(app.id)
                    Spacer(minLength: 12)
                    Text(ActivityDisplay.duration(app.seconds)).monospacedDigit()
                    Text(app.share.formatted(.percent.precision(.fractionLength(1))))
                        .foregroundStyle(.secondary).monospacedDigit()
                        .frame(width: 68, alignment: .trailing)
                }
                ProgressView(value: app.share, total: 1)
                    .tint(.blue)
                    .accessibilityLabel("\(app.name) 占比")
                    .accessibilityValue(app.share.formatted(.percent.precision(.fractionLength(1))))
            }
        }
    }
}

struct StatisticsOverview: View {
    let rows: [HourMetric]
    let records: [UsageRecord]
    @AppStorage("metrics.keyboard") private var keyboard = false
    @AppStorage("metrics.mouse") private var mouse = false
    @AppStorage("metrics.active") private var active = false

    var body: some View {
        let data = ActivitySummary(rows: rows, records: records)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("统计总览").font(.title2.bold())
                Text("跟随上方日期与应用筛选；快捷键包括已有每日记录，不受排行榜搜索或隐藏影响。")
                    .font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                    metricCard("主键按下", value: ActivityDisplay.count(data.keyPresses), symbol: "keyboard", note: "普通打字与快捷键主键", enabled: keyboard)
                    metricCard("快捷键", value: data.shortcutCount.formatted(), symbol: "command", note: "组合键、独立 F 键与支持的系统键", enabled: nil)
                    metricCard("鼠标点击", value: ActivityDisplay.count(data.mouseClicks), symbol: "computermouse", note: "左键、右键与其他按钮合计", enabled: mouse)
                    metricCard("活跃时长", value: ActivityDisplay.duration(data.activeSeconds), symbol: "clock", note: "前台应用活跃时间合计", enabled: active)
                    metricCard("最常用 App", value: data.appRankings.first?.name ?? "暂无数据", symbol: "app", note: data.appRankings.first.map { "按活跃时长 · \(ActivityDisplay.duration($0.seconds))" } ?? "以当前范围内的活跃时长排名", enabled: active)
                }
                Divider()
                Text("采集设置").font(.headline)
                Toggle("统计全部主键", isOn: $keyboard)
                Toggle("统计鼠标点击、滚动与移动", isOn: $mouse)
                Toggle("统计前台应用活跃时长", isOn: $active)
                Text("开关仅控制后续采集，关闭后保留历史；顶部暂停会停止全部采集。主键与快捷键存在重叠，不能相加作为总输入次数。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("主键不是输入字符数，也不单独累计修饰键。活跃时长以 60 秒无操作判为空闲，不累计锁屏、睡眠和暂停。小时指标只覆盖开启采集后的时段，不补算历史；零值可能代表尚未采集。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }
    }

    private func metricCard(_ title: String, value: String, symbol: String, note: String, enabled: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(.secondary)
            Text(value).font(.system(size: 27, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6).help(value)
            Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text(enabled.map { $0 ? "采集已开启" : "采集未开启 · 保留历史" } ?? "跟随顶部统计状态")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

private enum ActivityDisplay {
    static func count(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 秒" }
        let rounded = Int(min(seconds.rounded(.down), Double(Int.max / 2)))
        if rounded < 60 { return rounded == 0 ? "不足 1 秒" : "\(rounded) 秒" }
        let hours = rounded / 3600
        let minutes = (rounded % 3600) / 60
        if hours == 0 { return "\(minutes) 分钟" }
        return minutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(minutes) 分钟"
    }
}

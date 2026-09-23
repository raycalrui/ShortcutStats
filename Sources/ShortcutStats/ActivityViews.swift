import SwiftUI
import Charts
import AppKit

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
                Text(L10n.format("移动：%.0f 事件单位 · 滚动：%.0f 点 / %.0f 行", total("mouse.distance"), total("mouse.scroll.pixels"), total("mouse.scroll.lines")))
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
                        BarMark(x: .value(L10n.string("小时"), point.date), y: .value(L10n.string("用量"), metric == "active.seconds" ? point.value / 60 : point.value))
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
            Text(L10n.string(title)).font(.caption)
            Text(value.formatted(.number.precision(.fractionLength(0)))).font(.title2)
            if !enabled { Text("采集未开启").font(.caption2).foregroundStyle(.secondary) }
        }
    }
}


/// Both views receive the same date/app-filtered range as the other statistics tabs.
struct AppUsageRankingView: View {
    let rows: [HourMetric]
    let records: [UsageRecord]
    @AppStorage("metrics.active") private var active = false
    @State private var selectedApp: AppActivityRanking?

    private var summary: ActivitySummary { ActivitySummary(rows: rows, records: records) }

    var body: some View {
        let data = summary
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("应用使用时长").font(.title2.bold())
                    Spacer()
                    Text(L10n.format("合计 %@", ActivityDisplay.duration(data.activeSeconds)))
                        .font(.headline).monospacedDigit()
                }
                Text("按当前日期与应用范围统计前台活跃时长；占比以当前范围的总活跃时长为分母。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("统计前台应用活跃时长", isOn: $active)
                Text(L10n.string(active ? "采集已开启；60 秒无操作视为空闲，不累计锁屏、睡眠和暂停。" : "采集未开启；已有历史仍会显示，开启后开始累计新数据。"))
                    .font(.caption).foregroundStyle(.secondary)
                if data.appRankings.isEmpty {
                    ContentUnavailableView(
                        "暂无应用时长数据",
                        systemImage: "clock",
                        description: Text(L10n.string(active ? "正常使用 Mac 后会出现数据，也可以调整上方日期与应用筛选。" : "开启活跃时长采集后，正常使用 Mac 即可开始累计。"))
                    ).frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(data.appRankings.enumerated()), id: \.element.id) { index, app in
                            Button {
                                selectedApp = app
                            } label: {
                                rankingRow(app, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("打开应用详情")
                        }
                    }
                }
                Text("时长来自启用采集后的小时汇总，不推算旧数据或未运行时段。前台活跃时长不等于 App 打开时长。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }
        .sheet(item: $selectedApp) { app in
            AppDetailView(app: app, rows: rows, records: records)
        }
    }

    private func rankingRow(_ app: AppActivityRanking, rank: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(rank)).font(.headline).foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing).padding(.top, 2)
            AppIdentityIcon(bundleID: app.id, size: 38)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.localizedAppName(app.name)).font(.headline).lineLimit(1).help(app.id)
                    Spacer(minLength: 12)
                    Text(ActivityDisplay.duration(app.seconds)).monospacedDigit()
                    Text(app.share.formatted(.percent.precision(.fractionLength(1))))
                        .foregroundStyle(.secondary).monospacedDigit()
                        .frame(width: 68, alignment: .trailing)
                }
                ProgressView(value: app.share, total: 1)
                    .tint(.blue)
                    .accessibilityLabel(L10n.format("%@ 占比", L10n.localizedAppName(app.name)))
                    .accessibilityValue(app.share.formatted(.percent.precision(.fractionLength(1))))
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
    }
}

/// Resolves installed application icons once and retains them only in memory.
/// Bundle IDs are used as the cache key so applications with the same display name remain distinct.
@MainActor
private final class AppIconCache {
    static let shared = AppIconCache()

    private var icons: [String: NSImage] = [:]
    private let fallback = NSImage(systemSymbolName: "app", accessibilityDescription: L10n.string("应用")) ?? NSImage()

    func icon(for bundleID: String) -> NSImage {
        if let icon = icons[bundleID] { return icon }
        let icon: NSImage
        if !bundleID.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = fallback
        }
        icons[bundleID] = icon
        return icon
    }
}

private struct AppIdentityIcon: View {
    let bundleID: String
    let size: CGFloat
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(systemName: "app")
                    .resizable().scaledToFit().padding(size * 0.14)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: bundleID) {
            icon = AppIconCache.shared.icon(for: bundleID)
        }
    }
}

private struct AppDetailView: View {
    let app: AppActivityRanking
    let rows: [HourMetric]
    let records: [UsageRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var hoveredHour: Date?

    private var appRows: [HourMetric] { rows.filter { $0.appID == app.id } }
    private var appRecords: [UsageRecord] { records.filter { $0.appID == app.id } }

    private var activeSeconds: Double {
        appRows.filter { $0.metric == "active.seconds" && $0.value.isFinite && $0.value > 0 }
            .reduce(0) { $0 + $1.value }
    }

    private var keyPresses: Double {
        appRows.filter { $0.metric.hasPrefix("key:") && $0.metric.count > 4 && $0.value.isFinite && $0.value > 0 }
            .reduce(0) { $0 + $1.value }
    }

    private var shortcutCount: Int {
        appRecords.reduce(0) { $0 + max(0, $1.count) }
    }

    private var mouseClicks: Double {
        appRows.filter { ["mouse.left", "mouse.right", "mouse.other"].contains($0.metric) && $0.value.isFinite && $0.value > 0 }
            .reduce(0) { $0 + $1.value }
    }

    private var hourlyActivity: [(hour: Date, seconds: Double)] {
        Dictionary(grouping: appRows.filter {
            $0.metric == "active.seconds" && $0.value.isFinite && $0.value > 0
        }, by: \.hour)
        .map { (hour: $0.key, seconds: $0.value.reduce(0) { $0 + $1.value }) }
        .sorted { $0.hour < $1.hour }
    }

    private var hourlyPeak: (hour: Date, seconds: Double)? {
        hourlyActivity.max { lhs, rhs in
            lhs.seconds == rhs.seconds ? lhs.hour > rhs.hour : lhs.seconds < rhs.seconds
        }
    }

    private var isSingleDayChart: Bool {
        guard let first = hourlyActivity.first, let last = hourlyActivity.last else { return true }
        return Calendar.current.isDate(first.hour, inSameDayAs: last.hour)
    }

    private var hourlyDomain: ClosedRange<Date> {
        guard let first = hourlyActivity.first, let last = hourlyActivity.last else {
            let now = Date()
            return now...now.addingTimeInterval(3600)
        }
        if isSingleDayChart, let day = Calendar.current.dateInterval(of: .day, for: first.hour) {
            return day.start...day.end
        }
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: last.hour) ?? last.hour.addingTimeInterval(3600)
        return first.hour...end
    }

    private var hourlyMaximum: Double {
        let peak = max(1, (hourlyPeak?.seconds ?? 0) / 60)
        let step = peak <= 20 ? 5.0 : peak <= 60 ? 10.0 : peak <= 120 ? 20.0 : 30.0
        return max(step * 2, ceil((peak * 1.1) / step) * step)
    }

    private var hoveredActivity: (hour: Date, seconds: Double)? {
        guard let hoveredHour,
              let bucket = Calendar.current.dateInterval(of: .hour, for: hoveredHour)?.start else { return nil }
        return hourlyActivity.first { abs($0.hour.timeIntervalSince(bucket)) < 1 }
    }

    private var topShortcuts: [Ranking] {
        Dictionary(grouping: appRecords.filter { $0.count > 0 }, by: \.shortcut)
            .map { Ranking(shortcut: $0.key, count: $0.value.reduce(0) { $0 + $1.count }) }
            .sorted { $0.count == $1.count ? $0.shortcut < $1.shortcut : $0.count > $1.count }
            .prefix(10).map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                AppIdentityIcon(bundleID: app.id, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.title2.bold()).lineLimit(1)
                    Text(app.id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        detailMetric("活跃时长", ActivityDisplay.duration(activeSeconds), symbol: "clock")
                        detailMetric("当前范围占比", app.share.formatted(.percent.precision(.fractionLength(1))), symbol: "chart.pie")
                        detailMetric("主键按下", ActivityDisplay.count(keyPresses), symbol: "keyboard")
                        detailMetric("快捷键", shortcutCount.formatted(), symbol: "command")
                        detailMetric("鼠标点击", ActivityDisplay.count(mouseClicks), symbol: "computermouse")
                    }

                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("每小时活跃趋势").font(.headline)
                        Spacer()
                        if let peak = hourlyPeak {
                            Text(L10n.format("%d 个活跃小时 · 峰值 %@", hourlyActivity.count, peakLabel(peak.hour)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if hourlyActivity.isEmpty {
                        Text("当前筛选范围内暂无活跃时长数据。")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        Chart {
                            ForEach(hourlyActivity, id: \.hour) { point in
                                RectangleMark(
                                    xStart: .value(L10n.string("小时开始"), point.hour.addingTimeInterval(360)),
                                    xEnd: .value(L10n.string("小时结束"), point.hour.addingTimeInterval(3240)),
                                    yStart: .value(L10n.string("起点"), 0.0),
                                    yEnd: .value(L10n.string("分钟"), point.seconds / 60)
                                )
                                .cornerRadius(3)
                            }

                            if let hovered = hoveredActivity {
                                RuleMark(x: .value(L10n.string("选中小时"), hovered.hour.addingTimeInterval(1800)))
                                    .foregroundStyle(.secondary.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .annotation(position: .top, spacing: 6) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(hourRangeLabel(hovered.hour)).fontWeight(.semibold)
                                            Text(L10n.format("活跃 %@", ActivityDisplay.duration(hovered.seconds)))
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                                    }
                            }
                        }
                        .chartXScale(domain: hourlyDomain)
                        .chartYScale(domain: 0...hourlyMaximum)
                        .chartXAxis {
                            if isSingleDayChart {
                                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) { Text(hourLabel(date)) }
                                    }
                                }
                            } else {
                                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.locale(AppLanguage.locale).month().day().hour()))
                                        }
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: [0, hourlyMaximum / 2, hourlyMaximum]) {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel()
                            }
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let location):
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            let frame = geometry[plotFrame]
                                            let x = location.x - frame.origin.x
                                            hoveredHour = x >= 0 && x <= frame.width ? proxy.value(atX: x) : nil
                                        case .ended:
                                            hoveredHour = nil
                                        }
                                    }
                            }
                        }
                        .frame(height: 150)
                        .chartYAxisLabel(L10n.string("分钟"))
                    }

                    Divider()
                    Text("常用快捷键").font(.headline)
                    if topShortcuts.isEmpty {
                        Text("当前筛选范围内暂无快捷键数据。")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(topShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                                    Text(L10n.localizedShortcutName(shortcut.shortcut)).font(.system(.body, design: .monospaced).bold())
                                    Spacer()
                                    Text(L10n.format("%d 次", shortcut.count)).monospacedDigit().foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 9)
                                if index < topShortcuts.count - 1 { Divider() }
                            }
                        }
                    }

                    Text("详情严格按应用标识符筛选，并跟随主窗口的日期范围。活跃时长为前台且未空闲的采样时间。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 620, idealHeight: 720)
    }

    private func detailMetric(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.string(title), systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.locale(AppLanguage.locale).hour(.twoDigits(amPM: .omitted)))
    }

    private func hourRangeLabel(_ date: Date) -> String {
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(3600)
        let range = "\(hourLabel(date)):00–\(hourLabel(end)):00"
        return isSingleDayChart ? range : "\(date.formatted(.dateTime.locale(AppLanguage.locale).month().day())) · \(range)"
    }

    private func peakLabel(_ date: Date) -> String {
        let hour = "\(hourLabel(date)):00"
        return isSingleDayChart ? hour : "\(date.formatted(.dateTime.locale(AppLanguage.locale).month().day())) \(hour)"
    }
}

struct StatisticsOverview: View {
    let rows: [HourMetric]
    let records: [UsageRecord]
    @AppStorage("metrics.keyboard") private var keyboard = false
    @AppStorage("metrics.mouse") private var mouse = false
    @AppStorage("metrics.active") private var active = false
    @AppStorage("metrics.network") private var network = false

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
                    metricCard("最常用 App", value: data.appRankings.first.map { L10n.localizedAppName($0.name) } ?? L10n.string("暂无数据"), symbol: "app", note: data.appRankings.first.map { L10n.format("按活跃时长 · %@", ActivityDisplay.duration($0.seconds)) } ?? L10n.string("以当前范围内的活跃时长排名"), enabled: active)
                    let networkBytes = rows.filter { $0.metric == "network.download.bytes" || $0.metric == "network.upload.bytes" }.reduce(0) { $0 + $1.value }
                    metricCard("网络流量", value: ActivityDisplay.bytes(networkBytes), symbol: "network", note: "整机活动接口上传与下载合计", enabled: network)
                }
                Divider()
                Text("采集设置").font(.headline)
                Toggle("统计全部主键", isOn: $keyboard)
                Toggle("统计鼠标点击、滚动与移动", isOn: $mouse)
                Toggle("统计前台应用活跃时长", isOn: $active)
                Toggle("统计整机网络流量", isOn: $network)
                Text("开关仅控制后续采集，关闭后保留历史；顶部暂停会停止全部采集。主键与快捷键存在重叠，不能相加作为总输入次数。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("主键不是输入字符数，也不单独累计修饰键。活跃时长以 60 秒无操作判为空闲，不累计锁屏、睡眠和暂停。小时指标只覆盖开启采集后的时段，不补算历史；零值可能代表尚未采集。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }
    }

    private func metricCard(_ title: String, value: String, symbol: String, note: String, enabled: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.string(title), systemImage: symbol).font(.headline).foregroundStyle(.secondary)
            Text(value).font(.system(size: 27, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6).help(value)
            Text(L10n.string(note)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text(L10n.string(enabled.map { $0 ? "采集已开启" : "采集未开启 · 保留历史" } ?? "跟随顶部统计状态"))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

private enum ActivityDisplay {
    static func bytes(_ value: Double) -> String {
        L10n.byteCount(value)
    }

    static func count(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    static func duration(_ seconds: Double) -> String {
        L10n.duration(seconds)
    }
}

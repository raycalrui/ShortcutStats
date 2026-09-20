import SwiftUI

/// Today's all-app summary is independent of the dashboard's date and app filters.
struct QuickStatsView: View {
    @ObservedObject var monitor: Monitor
    let openDashboard: () -> Void
    @AppStorage("metrics.keyboard") private var keyboard = false
    @AppStorage("metrics.mouse") private var mouse = false
    @AppStorage("metrics.active") private var active = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let day = Statistics.dayString(context.date)
            let data = ActivitySummary(
                rows: monitor.activityRows(from: day, through: day, appID: ""),
                records: monitor.records.filter { $0.day == day }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("今日统计").font(.headline)
                        Spacer()
                        Text(context.date.formatted(.dateTime.month().day()))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Label(monitor.status, systemImage: monitor.health.symbol)
                        .font(.caption)
                        .foregroundStyle(monitor.health == .recording ? Color.green : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    metric("主键按下", value: count(data.keyPresses), symbol: "keyboard", enabled: keyboard)
                    metric("快捷键", value: data.shortcutCount.formatted(), symbol: "command")
                    metric("鼠标点击", value: count(data.mouseClicks), symbol: "computermouse", enabled: mouse)
                    metric("活跃时长", value: duration(data.activeSeconds), symbol: "clock", enabled: active)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("最常用 App · 按活跃时长").font(.caption).foregroundStyle(.secondary)
                        Text(data.appRankings.first?.name ?? "暂无数据")
                            .font(.headline).lineLimit(2)
                        if let app = data.appRankings.first {
                            Text("\(duration(app.seconds)) · \(app.share.formatted(.percent.precision(.fractionLength(1))))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if !active { disabledLabel }
                    }
                    Text("全部应用 · 主键与快捷键有重叠，不相加。")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let error = monitor.activityError {
                        Text(error).font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                    HStack {
                        Button(monitor.wantsTracking ? "暂停统计" : "开始统计") {
                            if monitor.wantsTracking { monitor.stop() } else { monitor.start() }
                        }
                        Spacer()
                        Button("打开主窗口", action: openDashboard)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320, height: 470)
    }

    private func metric(_ title: String, value: String, symbol: String, enabled: Bool? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: symbol).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value).fontWeight(.semibold).monospacedDigit()
            }
            if enabled == false { disabledLabel }
        }
    }

    private var disabledLabel: some View {
        Text("采集未开启 · 保留历史").font(.caption2).foregroundStyle(.secondary)
    }

    private func count(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 秒" }
        let whole = Int(min(seconds.rounded(.down), Double(Int.max / 2)))
        if whole < 60 { return whole == 0 ? "不足 1 秒" : "\(whole) 秒" }
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        if hours == 0 { return "\(minutes) 分钟" }
        return minutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(minutes) 分钟"
    }
}

import SwiftUI

/// Today's all-app summary is independent of the dashboard's date and app filters.
struct QuickStatsView: View {
    @ObservedObject var monitor: Monitor
    let openDashboard: () -> Void
    @AppStorage("metrics.keyboard") private var keyboard = false
    @AppStorage("metrics.mouse") private var mouse = false
    @AppStorage("metrics.active") private var active = false
    @AppStorage("metrics.network") private var network = false
    @AppStorage("quick.show.mainKeys") private var showMainKeys = true
    @AppStorage("quick.show.shortcuts") private var showShortcuts = true
    @AppStorage("quick.show.mouse") private var showMouse = true
    @AppStorage("quick.show.active") private var showActive = true
    @AppStorage("quick.show.network") private var showNetwork = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let day = Statistics.dayString(context.date)
            let activityRows = monitor.activityRows(from: day, through: day, appID: "")
            let data = ActivitySummary(
                rows: activityRows,
                records: monitor.records.filter { $0.day == day }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日统计").font(.headline)
                            Text("全部应用")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(displayDate(context.date))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Label(monitor.status, systemImage: monitor.health.symbol)
                        .font(.caption)
                        .foregroundStyle(monitor.health == .recording ? Color.green : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    if showMainKeys { metric("主键按下", value: count(data.keyPresses), symbol: "keyboard", enabled: keyboard) }
                    if showShortcuts { metric("快捷键", value: data.shortcutCount.formatted(), symbol: "command") }
                    if showMouse { metric("鼠标点击", value: count(data.mouseClicks), symbol: "computermouse", enabled: mouse) }
                    if showActive { metric("活跃时长", value: duration(data.activeSeconds), symbol: "clock", enabled: active) }
                    if showNetwork {
                        let download = rows(data: activityRows, metric: "network.download.bytes")
                        let upload = rows(data: activityRows, metric: "network.upload.bytes")
                        metric("网络流量", value: "↓ \(L10n.byteCount(download))  ↑ \(L10n.byteCount(upload))", symbol: "network", enabled: network)
                    }
                    if showActive { VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("最常用 App")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(data.appRankings.first.map { L10n.localizedAppName($0.name) } ?? L10n.string("暂无数据"))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                        }
                        if let app = data.appRankings.first {
                            Text(L10n.format("按活跃时长 · %@ · %@", duration(app.seconds), app.share.formatted(.percent.locale(AppLanguage.locale).precision(.fractionLength(1)))))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if !active { disabledLabel }
                    } }
                    if let error = monitor.activityError {
                        Text(error).font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                    HStack {
                        Button(L10n.string(monitor.wantsTracking ? "暂停统计" : "开始统计")) {
                            if monitor.wantsTracking { monitor.stop() } else { monitor.start() }
                        }
                        Spacer()
                        SettingsLink {
                            Image(systemName: "gearshape")
                        }
                        .help("打开设置")
                        .accessibilityLabel("设置")
                        Button("打开主窗口", action: openDashboard)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320, height: 340)
    }

    private func metric(_ title: String, value: String, symbol: String, enabled: Bool? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Label(L10n.string(title), systemImage: symbol).foregroundStyle(.secondary)
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
    private func rows(data: [HourMetric], metric: String) -> Double {
        data.filter { $0.metric == metric }.reduce(0) { $0 + $1.value }
    }
    private func displayDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(AppLanguage.locale).month().day())
    }

    private func duration(_ seconds: Double) -> String {
        L10n.duration(seconds)
    }
}

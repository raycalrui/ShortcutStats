import SwiftUI
import AppKit
import Carbon
import ServiceManagement
import Combine

@main
struct ShortcutStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { StartupSettings() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var window: NSWindow!
    private let monitor = Monitor()
    private var statusSubscription: AnyCancellable?
    private var preferencesSubscription: AnyCancellable?
    private var loginLaunch = false
    private let quickPopover = NSPopover()

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        loginLaunch = event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarDefaults.register()
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ShortcutStats")
        item.button?.target = self
        item.button?.action = #selector(toggleQuickStats)
        quickPopover.behavior = .transient
        quickPopover.contentSize = NSSize(width: 320, height: 340)
        quickPopover.contentViewController = NSHostingController(rootView: QuickStatsView(monitor: monitor) { [weak self] in
            self?.showWindow()
        })
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 920),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = Bundle.main.bundleIdentifier == "cc.raycal.ShortcutStats.local"
            ? "ShortcutStats（本机开发版）" : "ShortcutStats"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 820, height: 820)
        window.contentView = NSHostingView(rootView: Dashboard(monitor: monitor))
        window.center()
        statusSubscription = Publishers.CombineLatest(monitor.$health, monitor.$activityRevision).sink { [weak self] state, _ in
            DispatchQueue.main.async { self?.updateStatusItem(state: state) }
        }
        preferencesSubscription = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateStatusItem(state: self?.monitor.health) } }
        _ = UpdateController.shared
        monitor.restoreTracking()
        if !loginLaunch { showWindow() }
    }
    private func updateStatusItem(state: TrackingState?) {
        guard let state, let button = item.button else { return }
        let day = Statistics.dayString(Date())
        let rows = monitor.activityRows(from: day, through: day, appID: "")
        let summary = ActivitySummary(rows: rows, records: monitor.records.filter { $0.day == day })
        let mode = StatusItemMetric(rawValue: UserDefaults.standard.string(forKey: "quick.statusMetric") ?? "") ?? .icon
        let title: String
        switch mode {
        case .icon: title = ""
        case .shortcuts: title = summary.shortcutCount.formatted()
        case .mainKeys: title = summary.keyPresses.formatted(.number.precision(.fractionLength(0)))
        case .mouseClicks: title = summary.mouseClicks.formatted(.number.precision(.fractionLength(0)))
        case .activeTime: title = Self.shortDuration(summary.activeSeconds)
        case .networkDownload:
            let value = rows.filter { $0.metric == "network.download.bytes" }.reduce(0) { $0 + $1.value }
            title = Self.byteCount(value)
        }
        item.length = title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
        button.title = title.isEmpty ? "" : " " + title
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.toolTip = "ShortcutStats · \(state.title)" + (title.isEmpty ? "" : " · \(mode.title) \(title)")
        button.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: state.title)
    }
    private static func shortDuration(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)h\(minutes % 60)m" : "\(minutes)m"
    }
    private static func byteCount(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(min(max(value, 0), Double(Int64.max))), countStyle: .file)
    }

    @objc private func showWindow() {
        quickPopover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    @objc private func toggleQuickStats() {
        guard let button = item.button else { return }
        if quickPopover.isShown { quickPopover.performClose(nil) }
        else {
            NSApp.activate(ignoringOtherApps: true)
            quickPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop(persistPause: false) }
}

struct Dashboard: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject private var updater = UpdateController.shared
    private var days: Int { monitor.days }
    private var appID: String { monitor.selectedAppID }

    @State private var startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
    @State private var endDate = Date()
    @State private var selectedDay = Date()
    @State private var search = ""
    @State private var section = "统计总览"
    @State private var showHidden = false
    @State private var showDataManagement = false
    @AppStorage("hiddenShortcuts") private var hiddenJSON = "[]"
    private var hidden: Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: Data(hiddenJSON.utf8))) ?? [])
    }
    private func setHidden(_ value: Set<String>) {
        if let data = try? JSONEncoder().encode(value.sorted()), let text = String(data: data, encoding: .utf8) { hiddenJSON = text }
    }
    private var since: String {
        if days == -2 { return Statistics.dayString(selectedDay) }
        if days == -1 { return Statistics.dayString(startDate) }
        if days == 0 { return (monitor.records.map(\.day) + monitor.activityRows(from: "", through: "9999", appID: "").map(\.day)).min() ?? Statistics.dayString(Date()) }
        return Statistics.dayString(Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date())!)
    }
    private var through: String { Statistics.dayString(days == -2 ? selectedDay : days == -1 ? endDate : Date()) }
    private var dayAnchor: Date { days == -2 ? selectedDay : days == -1 ? endDate : Date() }
    private func moveDay(_ direction: Int) {
        selectedDay = DayNavigation.moved(dayAnchor, by: direction)
        monitor.days = -2
    }
    private var invalidRange: Bool { since > through }
    private var selectedRecords: [UsageRecord] {
        Statistics.filtered(monitor.records, from: since, through: through, appID: appID)
    }
    private var selectedActivityRows: [HourMetric] {
        let scoped = monitor.activityRows(from: since, through: through, appID: appID)
        guard !appID.isEmpty else { return scoped }
        return scoped + monitor.activityRows(from: since, through: through, appID: NetworkTracker.systemAppID)
    }
    private var calendarRecords: [UsageRecord] {
        Statistics.filtered(monitor.records, from: "", through: "9999-12-31", appID: appID)
    }
    private var calendarRows: [HourMetric] {
        let scoped = monitor.activityRows(from: "", through: "9999-12-31", appID: appID)
        guard !appID.isEmpty else { return scoped }
        return scoped + monitor.activityRows(from: "", through: "9999-12-31", appID: NetworkTracker.systemAppID)
    }
    private var networkRows: [HourMetric] {
        monitor.activityRows(from: since, through: through, appID: NetworkTracker.systemAppID)
    }
    private var visibleRecords: [UsageRecord] {
        Statistics.filtered(selectedRecords, from: since, through: through, appID: appID, search: search, hidden: hidden)
    }
    private var ranking: [Ranking] { Statistics.rankings(visibleRecords, since: "", appID: "") }
    private var apps: [(id: String, name: String)] {
        var result: [String: String] = [:]
        for record in monitor.records { result[record.appID] = record.appName }
        for row in monitor.activityRows(from: "", through: "9999", appID: "") where row.appID != NetworkTracker.systemAppID { result[row.appID] = row.appName }
        return result.map { (id: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("我最常用的快捷键").font(.largeTitle.bold())
                    Label(monitor.status, systemImage: monitor.health.symbol)
                        .font(.subheadline).foregroundStyle(monitor.running ? .green : .secondary)
                }
                Spacer()
                Button(monitor.wantsTracking ? "暂停统计" : "开始统计") {
                    if monitor.wantsTracking { monitor.stop() } else { monitor.start() }
                }
            }
            HStack {
                Picker("时间", selection: $monitor.days) {
                    Text("今天").tag(1)
                    Text("按天查看").tag(-2)
                    Text("近 7 天").tag(7)
                    Text("近 30 天").tag(30)
                    Text("全部").tag(0)
                    Text("自定义").tag(-1)
                }.frame(width: 200)
                Picker("应用", selection: $monitor.selectedAppID) {
                    Text("全部应用").tag("")
                    ForEach(apps, id: \.id) { app in Text(app.name).tag(app.id) }
                }.frame(maxWidth: 260)
                Spacer()
                Menu("导出 CSV") {
                    Button("日期与应用范围（全部组合键）") { monitor.export(since: since, through: through, appID: appID) }
                    Button("当前排行榜（含搜索与隐藏过滤）") { monitor.export(since: since, through: through, appID: appID, search: search, hidden: hidden) }
                    Divider()
                    ForEach(ActivityCSVKind.allCases, id: \.self) { kind in
                        Button(kind.title) { monitor.exportActivityCSV(kind: kind, from: since, through: through, appID: appID) }
                    }
                }.disabled(invalidRange)
            }
            HStack(spacing: 12) {
                Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }
                    .help("查看前一天").accessibilityLabel("查看前一天")
                if days == -2 {
                    DatePicker("日期", selection: $selectedDay, in: ...Date(), displayedComponents: .date)
                        .labelsHidden().fixedSize()
                } else {
                    Text(days == 1 ? "今天" : "按天浏览").foregroundStyle(.secondary)
                }
                Button { moveDay(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(!DayNavigation.canMoveForward(dayAnchor))
                    .help("查看后一天").accessibilityLabel("查看后一天")
                Button("回到今天") { selectedDay = Date(); monitor.days = 1 }
                if days != -2 && days != 1 {
                    Text("左箭头从当前范围的结束日向前查看").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if days == -1 {
                HStack {
                    DatePicker("开始", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    DatePicker("结束", selection: $endDate, in: ...Date(), displayedComponents: .date)
                }
            }
            Picker("统计视图", selection: $section) {
                ForEach(["统计总览", "排行榜", "应用时长", "每日趋势", "日历热力图", "键盘热力图", "网络流量", "键鼠与小时"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            if invalidRange {
                ContentUnavailableView("日期范围无效", systemImage: "calendar", description: Text("开始日期不能晚于结束日期。"))
                    .frame(maxHeight: .infinity)
            } else if section == "统计总览" {
                StatisticsOverview(rows: selectedActivityRows, records: selectedRecords)
            } else if section == "应用时长" {
                AppUsageRankingView(rows: selectedActivityRows, records: selectedRecords)
            } else if section == "排行榜" {
                HStack {
                    TextField("搜索组合键，例如 ⌘C 或 Space", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Button("已隐藏 (\(hidden.count))") { showHidden = true }
                }
                HStack(spacing: 28) {
                    Text("\(ranking.reduce(0) { $0 + $1.count }) 次使用").font(.title2.bold())
                    Text("\(ranking.count) 个组合键 · 当前展示").foregroundStyle(.secondary)
                }
                RankingList(ranking: ranking) { shortcut in setHidden(hidden.union([shortcut])) }
            } else if section == "每日趋势" {
                UsageTrend(records: selectedRecords, from: since, through: through)
            } else if section == "日历热力图" {
                CalendarHeatmapView(records: calendarRecords, rows: calendarRows, selectedDay: $selectedDay) { date in
                    selectedDay = date
                    monitor.days = -2
                }
            } else if section == "网络流量" {
                NetworkUsageView(rows: networkRows)
            } else if section == "键鼠与小时" {
                ActivityDashboard(rows: selectedActivityRows)
            } else {
                KeyboardHeatmapSection(records: selectedRecords, rows: selectedActivityRows)
            }
            if monitor.waitingForPermission {
                VStack(alignment: .leading, spacing: 8) {
                    Text(monitor.permissionHelp).font(.callout)
                    HStack {
                        Button("打开输入监控设置") { monitor.openPermissionSettings() }
                        Button("在 Finder 显示当前应用") { monitor.revealCurrentApp() }
                        Button("取消等待") { monitor.stop() }
                    }
                }
            }
            if let message = monitor.errorMessage { Text(message).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            if let activityError = monitor.activityError { Text(activityError).font(.caption).foregroundStyle(.red) }
            if let historyError = monitor.historyError { Text(historyError).font(.caption).foregroundStyle(.red) }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("统计含 ⌘ / ⌥ / ⌃ 的组合键、单独 F 键及可识别的媒体/亮度键；忽略长按重复。\n按前台应用归类；键位按美式 QWERTY 标记。数据仅保存在本机。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                Menu("数据备份") {
                    Button("导出完整备份…") { monitor.exportBackup() }
                    Button("从备份恢复…") { monitor.importBackup() }
                }
                Button("数据管理") { showDataManagement = true }
                Spacer()
                Button("检查更新…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
                Button("中断记录") { monitor.showInterruptions = true }
                SettingsLink { Text("设置") }
                Button("权限设置") {
                    monitor.openPermissionSettings()
                }
                Button("退出") { NSApp.terminate(nil) }
                }
            }
        }.padding(28).frame(minWidth: 650, minHeight: 430)
            .sheet(isPresented: $showHidden) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("已隐藏的组合键").font(.title2.bold())
                        Spacer()
                        Button("全部恢复") { setHidden([]) }.disabled(hidden.isEmpty)
                        Button("关闭") { showHidden = false }
                    }
                    Text("只影响排行榜和明确标注的排行榜导出；不删除记录，不影响趋势和热力图。")
                        .font(.caption).foregroundStyle(.secondary)
                    List(hidden.sorted(), id: \.self) { key in
                        HStack { Text(key); Spacer(); Button("恢复显示") { setHidden(hidden.subtracting([key])) } }
                    }
                }.padding(24).frame(width: 550, height: 360)
            }
            .sheet(isPresented: $monitor.showInterruptions) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("采集中断记录").font(.title2.bold())
                        Spacer()
                        Button("关闭") { monitor.showInterruptions = false }
                    }
                    Text("仅记录本 App 运行时发现的状态变化。检测存在约 2 秒延迟；没有记录不代表采集完整。无结束时间表示仍在持续或上次异常退出，不能据此推算离线时长。")
                        .font(.caption).foregroundStyle(.secondary)
                    List(monitor.interruptions.reversed()) { gap in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gap.reason.title)
                            Text(gap.start.formatted() + " → " + (gap.end?.formatted() ?? "持续中 / 结束未知"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(24).frame(width: 570, height: 400)
            }
            .sheet(isPresented: $showDataManagement) {
                DataManagementView(monitor: monitor)
            }
            .alert("输入监控权限尚未生效", isPresented: $monitor.showPermissionHelp) {
                Button("打开系统设置") { monitor.openPermissionSettings() }
                Button("稍后处理", role: .cancel) { }
            } message: {
                Text(monitor.permissionHelp)
            }
    }
}


private struct StartupSettings: View {
    @ObservedObject private var login = LoginItemController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置").font(.title2.bold())
            Toggle("登录时启动 ShortcutStats", isOn: Binding(
                get: { login.enabled }, set: { login.setEnabled($0) }
            ))
            Text("登录后在菜单栏后台运行，不弹出主窗口。上次手动暂停后，重新启动仍保持暂停。")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(login.statusText).font(.callout)
            if login.needsApproval {
                Button("打开系统登录项设置") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = login.error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            Text("建议先将 App 放到应用程序文件夹再开启，避免登录时运行构建目录中的旧副本。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            MenuBarSettingsSection()
            Divider()
            UpdateSettings()
        }
        .padding(24).frame(width: 480)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
        }
    }
}

private struct MenuBarSettingsSection: View {
    @AppStorage("quick.statusMetric") private var statusMetric = StatusItemMetric.icon.rawValue
    @AppStorage("quick.show.mainKeys") private var showMainKeys = true
    @AppStorage("quick.show.shortcuts") private var showShortcuts = true
    @AppStorage("quick.show.mouse") private var showMouse = true
    @AppStorage("quick.show.active") private var showActive = true
    @AppStorage("quick.show.network") private var showNetwork = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("菜单栏").font(.headline)
            Picker("图标旁显示", selection: $statusMetric) {
                ForEach(StatusItemMetric.allCases) { metric in Text(metric.title).tag(metric.rawValue) }
            }
            Text("快捷摘要显示项目").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Toggle("主键", isOn: $showMainKeys)
                Toggle("快捷键", isOn: $showShortcuts)
                Toggle("鼠标", isOn: $showMouse)
            }
            HStack {
                Toggle("活跃时长", isOn: $showActive)
                Toggle("网络流量", isOn: $showNetwork)
            }
            Text("菜单栏数字始终显示今天、全部应用的数据；快捷摘要也独立于主窗口筛选。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private final class LoginItemController: ObservableObject {
    static let shared = LoginItemController()
    @Published private(set) var enabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var statusText = ""
    @Published private(set) var error: String?

    init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
        switch status {
        case .enabled: statusText = "已开启登录启动"
        case .requiresApproval: statusText = "等待系统批准；请在登录项设置中允许 ShortcutStats。"
        case .notRegistered: statusText = "未开启登录启动"
        case .notFound: statusText = "系统无法找到应用，请从固定位置重新打开后再试。"
        @unknown default: statusText = "无法确认登录启动状态"
        }
    }

    func setEnabled(_ value: Bool) {
        error = nil
        do {
            if value {
                if SMAppService.mainApp.status != .enabled && SMAppService.mainApp.status != .requiresApproval {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            self.error = "无法更新登录启动设置：\(error.localizedDescription)"
        }
        refresh()
    }
}

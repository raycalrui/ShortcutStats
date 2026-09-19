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
    private var loginLaunch = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        loginLaunch = event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ShortcutStats")
        item.button?.target = self
        item.button?.action = #selector(showWindow)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ShortcutStats"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 700, height: 480)
        window.contentView = NSHostingView(rootView: Dashboard(monitor: monitor))
        window.center()
        statusSubscription = monitor.$health.sink { [weak self] state in
            self?.item.button?.toolTip = "ShortcutStats · " + state.title
            self?.item.button?.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: state.title)
        }
        _ = UpdateController.shared
        monitor.restoreTracking()
        if !loginLaunch { showWindow() }
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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

    private var since: String {
        guard days > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date())!)
    }
    private var ranking: [Ranking] { Statistics.rankings(monitor.records, since: since, appID: appID) }
    private var apps: [(id: String, name: String)] {
        var result: [String: String] = [:]
        for record in monitor.records { result[record.appID] = record.appName }
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
                    Text("近 7 天").tag(7)
                    Text("近 30 天").tag(30)
                    Text("全部").tag(0)
                }.frame(width: 200)
                Picker("应用", selection: $monitor.selectedAppID) {
                    Text("全部应用").tag("")
                    ForEach(apps, id: \.id) { app in Text(app.name).tag(app.id) }
                }.frame(maxWidth: 260)
                Spacer()
                Button("导出 CSV") { monitor.export(since: since, appID: appID) }
            }
            HStack(spacing: 28) {
                Text("\(ranking.reduce(0) { $0 + $1.count }) 次使用").font(.title2.bold())
                Text("\(ranking.count) 个组合键").foregroundStyle(.secondary)
            }
            if ranking.isEmpty {
                ContentUnavailableView("还没有统计数据", systemImage: "keyboard", description: Text("开始统计并授予输入监控权限，然后正常使用 Mac。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(ranking.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 16) {
                                Text(String(index + 1)).monospacedDigit().foregroundStyle(.secondary).frame(width: 30)
                                Text(entry.shortcut).font(.system(.body, design: .monospaced).bold()).frame(width: 160, alignment: .leading)
                                GeometryReader { geo in
                                    Capsule().fill(Color.accentColor.opacity(0.65))
                                        .frame(width: max(3, geo.size.width * Double(entry.count) / Double(ranking.first?.count ?? 1)))
                                }.frame(height: 9)
                                Text(entry.count.formatted()).monospacedDigit().frame(width: 80, alignment: .trailing)
                            }.padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
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
            if let historyError = monitor.historyError { Text(historyError).font(.caption).foregroundStyle(.red) }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("仅统计含 ⌘ / ⌥ / ⌃ 的组合键，忽略长按重复。\n按前台应用归类；键位按美式 QWERTY 标记。数据仅保存在本机。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
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
            UpdateSettings()
        }
        .padding(24).frame(width: 480)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
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

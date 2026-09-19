import SwiftUI
import AppKit

@main
struct ShortcutStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var window: NSWindow!
    private let monitor = Monitor()

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
        monitor.start(requestPermission: false)
        showWindow()
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop() }
}

struct Dashboard: View {
    @ObservedObject var monitor: Monitor
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
                    Label(monitor.status, systemImage: monitor.running ? "circle.fill" : "pause.circle")
                        .font(.subheadline).foregroundStyle(monitor.running ? .green : .secondary)
                }
                Spacer()
                Button(monitor.running ? "暂停统计" : "开始统计") {
                    if monitor.running { monitor.stop() } else { monitor.start() }
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
            if let message = monitor.errorMessage { Text(message).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            Divider()
            HStack(alignment: .top) {
                Text("仅统计含 ⌘ / ⌥ / ⌃ 的组合键，忽略长按重复。\n按前台应用归类；键位按美式 QWERTY 标记。数据仅保存在本机。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("权限设置") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                }
                Button("退出") { NSApp.terminate(nil) }
            }
        }.padding(28).frame(minWidth: 650, minHeight: 430)
    }
}

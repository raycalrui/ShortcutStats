import AppKit
import Carbon
import Combine

final class Monitor: ObservableObject {
    @Published var days = 7
    @Published var selectedAppID = ""
    @Published var records: [UsageRecord] = []
    @Published var status = "尚未开始"
    @Published var running = false
    @Published var errorMessage: String?
    @Published var showPermissionHelp = false
    @Published private(set) var waitingForPermission = false
    let permissionHelp = "当前进程尚未获得输入监控权限。如果系统设置中已经开启，请先退出并重新打开应用；仍无效时，移除旧条目，再添加当前应用并开启权限。重新编译或使用不同副本后，旧授权可能不再适用。"

    func openPermissionSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    func revealCurrentApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var foregroundID = "unknown"
    private var foregroundName = "Unknown"
    private var counts: [String: UsageRecord] = [:]
    private var dirty = false
    private var lastSave = Date.distantPast
    private var loadFailed = false
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let file: URL

    init() {
        file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShortcutStats/statistics.json")
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let loaded = try JSONDecoder().decode([UsageRecord].self, from: Data(contentsOf: file))
                for record in loaded { counts[key(record)] = record }
                records = loaded
            }
        } catch {
            loadFailed = true
            errorMessage = "无法读取历史数据，已停止记录以保护原文件：\(error.localizedDescription)"
        }
        updateForeground()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateForeground() }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.dirty { self.records = Array(self.counts.values) }
            if Date().timeIntervalSince(self.lastSave) >= 15 { self.save() }
            if self.waitingForPermission && CGPreflightListenEventAccess() {
                self.start(requestPermission: false)
            }
            if self.running {
                if !CGPreflightListenEventAccess() {
                    self.stop(persistPause: false)
                    self.status = "输入监控权限已撤销"
                } else if IsSecureEventInputEnabled() {
                    self.status = "安全输入启用中 · 暂时无法统计"
                } else {
                    self.status = "正在统计"
                }
            }
        }
    }

    private func key(_ r: UsageRecord) -> String { "\(r.day)\u{1F}\(r.appID)\u{1F}\(r.shortcut)" }
    private func updateForeground() {
        let app = NSWorkspace.shared.frontmostApplication
        foregroundID = app?.bundleIdentifier ?? "unknown"
        foregroundName = app?.localizedName ?? "Unknown"
    }

    func restoreTracking() {
        if UserDefaults.standard.bool(forKey: "trackingPaused") {
            status = "已暂停"
        } else {
            start(requestPermission: false)
        }
    }

    func start(requestPermission: Bool = true) {
        if requestPermission { UserDefaults.standard.set(false, forKey: "trackingPaused") }
        guard !running, !loadFailed else { return }
        var authorized = CGPreflightListenEventAccess()
        if !authorized && requestPermission {
            authorized = CGRequestListenEventAccess()
        }
        guard authorized || CGPreflightListenEventAccess() else {
            status = "输入监控权限尚未对当前应用生效"
            waitingForPermission = requestPermission || waitingForPermission
            if requestPermission { showPermissionHelp = true }
            return
        }
        waitingForPermission = false
        showPermissionHelp = false
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<Monitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else if type == .keyDown {
                monitor.receive(event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            status = "无法启动监听，请检查权限并重新打开 App"
            return
        }
        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        updateForeground()
        running = true
        status = "正在统计"
    }

    func stop(persistPause: Bool = true) {
        if persistPause { UserDefaults.standard.set(true, forKey: "trackingPaused") }
        waitingForPermission = false
        showPermissionHelp = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        running = false
        status = "已暂停"
        records = Array(counts.values)
        save()
    }

    private func receive(_ event: CGEvent) {
        guard running, let shortcut = Self.shortcut(for: event) else { return }
        let record = UsageRecord(day: formatter.string(from: Date()), appID: foregroundID,
                                 appName: foregroundName, shortcut: shortcut, count: 1)
        let id = key(record)
        if counts[id] != nil { counts[id]!.count += 1 } else { counts[id] = record }
        dirty = true
    }

    static func shortcut(for event: CGEvent) -> String? {
        guard event.type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }
        let flags = event.flags
        guard flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) else { return nil }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let prefix = (flags.contains(.maskControl) ? "⌃" : "")
            + (flags.contains(.maskAlternate) ? "⌥" : "")
            + (flags.contains(.maskShift) ? "⇧" : "")
            + (flags.contains(.maskCommand) ? "⌘" : "")
        return prefix + (Self.keyNames[code] ?? "Key\(code)")
    }

    func save() {
        guard dirty, !loadFailed else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(counts.values))
            try data.write(to: file, options: .atomic)
            dirty = false
            lastSave = Date()
        } catch { errorMessage = "保存失败：\(error.localizedDescription)" }
    }

    func export(since: String, appID: String) {
        records = Array(counts.values)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ShortcutStats-\(formatter.string(from: Date())).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let selected = records.filter { $0.day >= since && (appID.isEmpty || $0.appID == appID) }
            try Statistics.csv(selected).write(to: url, atomically: true, encoding: .utf8)
        } catch { errorMessage = "导出失败：\(error.localizedDescription)" }
    }

    static let keyNames: [Int64: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
        12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",
        22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",30:"]",31:"O",
        32:"U",33:"[",34:"I",35:"P",36:"↩",37:"L",38:"J",39:"'",40:"K",41:";",
        42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"Space",50:"`",
        51:"⌫",53:"Esc",65:"Num .",67:"Num *",69:"Num +",71:"Clear",75:"Num /",
        76:"Num ↩",78:"Num -",81:"Num =",82:"Num 0",83:"Num 1",84:"Num 2",
        85:"Num 3",86:"Num 4",87:"Num 5",88:"Num 6",89:"Num 7",91:"Num 8",92:"Num 9",
        96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",103:"F11",105:"F13",
        106:"F16",107:"F14",109:"F10",111:"F12",113:"F15",114:"Help",115:"Home",
        116:"Page Up",117:"⌦",118:"F4",119:"End",120:"F2",121:"Page Down",122:"F1",
        123:"←",124:"→",125:"↓",126:"↑"
    ]
}

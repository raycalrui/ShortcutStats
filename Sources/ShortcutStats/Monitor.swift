import AppKit
import Carbon
import Combine

final class Monitor: ObservableObject {
    @Published var activityRevision = 0
    @Published var activityError: String?
    private var activityStore: ActivityStore?
    private let activeTracker = ActiveTimeTracker()
    private var sessionInactive = false
    private var screenLocked = false
    private var screenSleeping = false
    private var preferencesObserver: NSObjectProtocol?
    private var lockObservers: [NSObjectProtocol] = []
    private var metricsSave = Date.distantPast
    private(set) var keyboardMetricsEnabled = UserDefaults.standard.bool(forKey: "metrics.keyboard")
    private(set) var mouseMetricsEnabled = UserDefaults.standard.bool(forKey: "metrics.mouse")
    private(set) var activeMetricsEnabled = UserDefaults.standard.bool(forKey: "metrics.active")
    func activityRows(from: String, through: String, appID: String) -> [HourMetric] {
        do { return try activityStore?.rows(from: from, through: through, appID: appID) ?? [] }
        catch {
            let message = "扩展统计读取失败：\(error.localizedDescription)"
            if activityError != message { DispatchQueue.main.async { [weak self] in self?.activityError = message } }
            return []
        }
    }
    private func sampleActivity() {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~UInt32(0))!)
        let slices = activeTracker.sample(at: Date(), uptime: ProcessInfo.processInfo.systemUptime,
            appID: foregroundID, appName: foregroundName, enabled: activeMetricsEnabled,
            eligible: running && wantsTracking && !sleeping && !sessionInactive && !screenLocked && !screenSleeping && !IsSecureEventInputEnabled(), idleSeconds: idle)
        for slice in slices { activityStore?.add(slice) }
    }
    private func flushActivity() {
        do { try activityStore?.flush() } catch { activityError = "扩展统计保存失败：\(error.localizedDescription)" }
    }
    @Published var days = 7
    @Published var selectedAppID = ""
    @Published var records: [UsageRecord] = []
    @Published var status = "尚未开始"
    @Published var running = false
    @Published private(set) var wantsTracking = false
    @Published private(set) var health: TrackingState = .paused
    @Published private(set) var interruptions: [TrackingGap] = []
    @Published var showInterruptions = false
    @Published private(set) var historyError: String?
    private var gapHistory = GapHistory()
    private var historyReadable = true
    private var historyDirty = false
    private var stateInitialized = false
    private var sleeping = false
    private var shuttingDown = false
    private var lastAttempt = Date.distantPast
    private var workspaceObservers: [NSObjectProtocol] = []
    private var historyURL: URL { file.deletingLastPathComponent().appendingPathComponent("interruptions.json") }
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
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any] {
            sessionInactive = !(session[kCGSessionOnConsoleKey as String] as? Bool ?? false)
            screenLocked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        } else { sessionInactive = true }
        file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShortcutStats/statistics.json")
        do { activityStore = try ActivityStore(url: file.deletingLastPathComponent().appendingPathComponent("activity.sqlite")) }
        catch { activityError = "扩展统计数据库不可用，停止新增扩展统计：\(error.localizedDescription)" }
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
        do {
            if FileManager.default.fileExists(atPath: historyURL.path) {
                gapHistory.entries = try JSONDecoder().decode([TrackingGap].self, from: Data(contentsOf: historyURL))
                interruptions = gapHistory.entries
            }
        } catch {
            historyReadable = false
            historyError = "中断记录读取失败，保留原文件：\(error.localizedDescription)"
        }
        let distributed = DistributedNotificationCenter.default()
        for (name, locked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            lockObservers.append(distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                self?.screenLocked = locked
                self?.activeTracker.reset()
            })
        }
        preferencesObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let mouse = UserDefaults.standard.bool(forKey: "metrics.mouse")
            let keyboard = UserDefaults.standard.bool(forKey: "metrics.keyboard")
            let active = UserDefaults.standard.bool(forKey: "metrics.active")
            if self.activeMetricsEnabled != active { self.activeTracker.reset() }
            let rebuild = self.mouseMetricsEnabled != mouse
            self.keyboardMetricsEnabled = keyboard
            self.mouseMetricsEnabled = mouse
            self.activeMetricsEnabled = active
            if rebuild { self.tearDownTap(); self.lastAttempt = .distantPast; self.reconcile() }
        }
        let center = NSWorkspace.shared.notificationCenter
        for (name, off) in [(NSWorkspace.screensDidSleepNotification, true), (NSWorkspace.screensDidWakeNotification, false)] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.screenSleeping = off
                self?.activeTracker.reset()
            })
        }
        for (name, inactive) in [(NSWorkspace.sessionDidResignActiveNotification, true), (NSWorkspace.sessionDidBecomeActiveNotification, false)] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sessionInactive = inactive
                self?.activeTracker.reset()
            })
        }
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.activeTracker.reset()
            self.flushActivity()
            self.sleeping = true
            self.reconcile()
            self.save()
            self.saveHistory()
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.sleeping = false
            self.lastAttempt = .distantPast
            self.updateForeground()
            self.reconcile()
        })
        updateForeground()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateForeground() }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sampleActivity()
            self.activityRevision &+= 1
            if Date().timeIntervalSince(self.metricsSave) >= 15 {
                self.flushActivity()
                self.metricsSave = Date()
            }
            if self.dirty { self.records = Array(self.counts.values) }
            if Date().timeIntervalSince(self.lastSave) >= 15 { self.save() }
            self.reconcile()
            if self.historyDirty { self.saveHistory() }
        }
    }

    private func key(_ r: UsageRecord) -> String { "\(r.day)\u{1F}\(r.appID)\u{1F}\(r.shortcut)" }
    private func updateForeground() {
        sampleActivity()
        let app = NSWorkspace.shared.frontmostApplication
        foregroundID = app?.bundleIdentifier ?? "unknown"
        foregroundName = app?.localizedName ?? "Unknown"
        sampleActivity()
    }

    func restoreTracking() {
        wantsTracking = !UserDefaults.standard.bool(forKey: "trackingPaused")
        reconcile()
    }

    func start(requestPermission: Bool = true) {
        wantsTracking = true
        UserDefaults.standard.set(false, forKey: "trackingPaused")
        if requestPermission && !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        lastAttempt = .distantPast
        reconcile()
        showPermissionHelp = requestPermission && waitingForPermission
    }

    private func transition(_ state: TrackingState) {
        running = state == .recording
        waitingForPermission = state == .permission
        if !waitingForPermission { showPermissionHelp = false }
        if !stateInitialized || health != state {
            stateInitialized = true
            health = state
            gapHistory.transition(to: state, at: Date())
            interruptions = gapHistory.entries
            historyDirty = true
        }
        if status != state.title { status = state.title }
    }

    private func reconcile() {
        guard !shuttingDown else { return }
        if let blocked = TrackingHealth.blockedState(wantsTracking: wantsTracking, dataValid: !loadFailed,
            sleeping: sleeping, authorized: CGPreflightListenEventAccess(), secureInput: IsSecureEventInputEnabled()) {
            tearDownTap()
            transition(blocked)
            return
        }
        if let tap, CFMachPortIsValid(tap), CGEvent.tapIsEnabled(tap: tap) {
            transition(.recording)
            return
        }
        if tap != nil { transition(.fault) }
        tearDownTap()
        // Failed recreation is retried at most once every five seconds.
        guard Date().timeIntervalSince(lastAttempt) >= 5 else { return }
        lastAttempt = Date()
        installTap()
    }

    private func installTap() {
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<Monitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                monitor.running = false
                // Recreate outside the callback; old tap is removed before any replacement.
                DispatchQueue.main.async { [weak monitor] in
                    guard let monitor, !monitor.shuttingDown else { return }
                    monitor.tearDownTap()
                    if monitor.wantsTracking { monitor.transition(.fault) }
                    monitor.reconcile()
                }
            } else {
                monitor.receive(event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << 14) | (mouseMetricsEnabled ? InputMetrics.eventMask : 0),
            callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            transition(.fault)
            return
        }
        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        updateForeground()
        if CGEvent.tapIsEnabled(tap: newTap) { transition(.recording) }
        else { tearDownTap(); transition(.fault) }
    }

    private func tearDownTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        running = false
    }

    func stop(persistPause: Bool = true) {
        sampleActivity()
        activeTracker.reset()
        flushActivity()
        if persistPause {
            wantsTracking = false
            UserDefaults.standard.set(true, forKey: "trackingPaused")
            reconcile()
        } else {
            shuttingDown = true
            timer?.invalidate()
            tearDownTap()
            gapHistory.finish(at: Date())
            historyDirty = true
        }
        showPermissionHelp = false
        records = Array(counts.values)
        save()
        saveHistory()
    }

    private func saveHistory() {
        guard historyDirty, historyReadable else { return }
        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(gapHistory.entries).write(to: historyURL, options: .atomic)
            historyDirty = false
            historyError = nil
        } catch { historyError = "中断记录保存失败：\(error.localizedDescription)" }
    }

    private func receive(_ event: CGEvent) {
        // Avoid work for high-rate pointer events when mouse collection is off.
        if event.type != .keyDown && event.type.rawValue != 14 && !mouseMetricsEnabled { return }
        guard running, wantsTracking, !sleeping, !sessionInactive, !screenLocked, !screenSleeping, !IsSecureEventInputEnabled() else { return }
        let now = Date()
        for delta in InputMetrics.decode(event, keyboard: keyboardMetricsEnabled, mouse: mouseMetricsEnabled) {
            activityStore?.add(delta, at: now, appID: foregroundID, appName: foregroundName)
        }
        guard let shortcut = Self.shortcut(for: event) else { return }
        activityStore?.add(MetricDelta(metric: "shortcut", value: 1), at: now, appID: foregroundID, appName: foregroundName)
        let record = UsageRecord(day: formatter.string(from: Date()), appID: foregroundID,
                                 appName: foregroundName, shortcut: shortcut, count: 1,
                                 modifierCounts: event.type == .keyDown ? Statistics.modifierCounts(flags: event.flags.rawValue) : [:])
        let id = key(record)
        if counts[id] != nil { counts[id]!.addOccurrence(modifiers: record.modifierCounts ?? [:]) } else { counts[id] = record }
        dirty = true
    }

    static func shortcut(for event: CGEvent) -> String? {
        // NX_SYSDEFINED / NX_SUBTYPE_AUX_CONTROL_BUTTONS, passive same-tap delivery.
        if event.type.rawValue == 14 {
            guard let native = NSEvent(cgEvent: event), native.type == .systemDefined else { return nil }
            return mediaShortcut(subtype: Int(native.subtype.rawValue), data: native.data1)
        }
        guard event.type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }
        let flags = event.flags
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let isFunction = Self.keyNames[code].map { name in
            name.hasPrefix("F") && Int(name.dropFirst()).map { (1...20).contains($0) } == true
        } ?? false
        guard isFunction || flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) else { return nil }
        let prefix = (flags.contains(.maskControl) ? "⌃" : "")
            + (flags.contains(.maskAlternate) ? "⌥" : "")
            + (flags.contains(.maskShift) ? "⇧" : "")
            + (flags.contains(.maskCommand) ? "⌘" : "")
        return prefix + (Self.keyNames[code] ?? "Key\(code)")
    }

    static func mediaShortcut(subtype: Int, data: Int) -> String? {
        // IOKit auxiliary button payload: high word = key type; low byte = repeat;
        // next byte = NX_KEYDOWN (0x0a) or NX_KEYUP (0x0b).
        guard subtype == 8, (data >> 8) & 0xff == 0x0a, data & 0xff == 0 else { return nil }
        return [0: "音量增加", 1: "音量降低", 2: "亮度增加", 3: "亮度降低",
                7: "静音", 16: "播放/暂停", 17: "下一首", 18: "上一首",
                19: "快进", 20: "快退", 21: "键盘背光增加", 22: "键盘背光降低",
                23: "键盘背光切换"][data >> 16 & 0xffff]
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

    func export(since: String, through: String = "9999-12-31", appID: String, search: String = "", hidden: Set<String> = []) {
        records = Array(counts.values)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ShortcutStats-\(formatter.string(from: Date())).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let selected = Statistics.filtered(records, from: since, through: through, appID: appID, search: search, hidden: hidden)
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

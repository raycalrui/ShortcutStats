import Foundation

enum TrackingState: String, Codable {
    case recording, paused, permission, secureInput, sleeping, fault, dataError

    var title: String {
        switch self {
        case .recording: return "正在统计"
        case .paused: return "手动暂停"
        case .permission: return "等待输入监控权限"
        case .secureInput: return "安全输入中 · 暂时无法统计"
        case .sleeping: return "系统睡眠中"
        case .fault: return "监听异常 · 正在重试"
        case .dataError: return "历史数据读取失败 · 已停止统计"
        }
    }
    var symbol: String {
        switch self {
        case .recording: return "keyboard"
        case .paused: return "pause.circle"
        case .sleeping: return "moon"
        case .secureInput: return "lock"
        default: return "exclamationmark.triangle"
        }
    }
}

enum TrackingHealth {
    // User intent has priority over environmental recovery signals.
    static func blockedState(wantsTracking: Bool, dataValid: Bool, sleeping: Bool,
                             authorized: Bool, secureInput: Bool) -> TrackingState? {
        if !dataValid { return .dataError }
        if !wantsTracking { return .paused }
        if sleeping { return .sleeping }
        if !authorized { return .permission }
        if secureInput { return .secureInput }
        return nil
    }
}

struct TrackingGap: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date?
    var reason: TrackingState
}

struct GapHistory {
    var entries: [TrackingGap] = []
    private var currentID: UUID?

    mutating func transition(to state: TrackingState, at date: Date) {
        if let id = currentID, let index = entries.firstIndex(where: { $0.id == id }) {
            if entries[index].reason == state { return }
            entries[index].end = max(date, entries[index].start)
            currentID = nil
        }
        guard state != .recording else { return }
        let gap = TrackingGap(start: date, reason: state)
        entries.append(gap)
        currentID = gap.id
    }

    mutating func finish(at date: Date) {
        if let id = currentID, let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].end = max(date, entries[index].start)
        }
        currentID = nil
    }
}

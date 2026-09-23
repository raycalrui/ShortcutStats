import Foundation

enum ActivityCSVKind: String, CaseIterable {
    case appTime, input, network, hourly

    var title: String {
        switch self {
        case .appTime: L10n.string("应用活跃时长")
        case .input: L10n.string("键鼠每日统计")
        case .network: L10n.string("网络每日统计")
        case .hourly: L10n.string("每小时统计")
        }
    }
    var filename: String {
        switch self {
        case .appTime: "ShortcutStats-AppTime.csv"
        case .input: "ShortcutStats-Input.csv"
        case .network: "ShortcutStats-Network.csv"
        case .hourly: "ShortcutStats-Hourly.csv"
        }
    }
}

enum ActivityCSV {
    private struct InputKey: Hashable {
        let day: String
        let appID: String
        let metric: String
    }

    // Caller supplies the selected date/app range. Shortcut search and hidden
    // rankings must not filter these independent activity measurements.
    static func csv(rows: [HourMetric], kind: ActivityCSVKind) -> String {
        let valid = rows.filter { $0.value.isFinite && $0.value >= 0 }
            .sorted { ($0.hour, $0.day, $0.appID, $0.metric, $0.appName, $0.value) <
                      ($1.hour, $1.day, $1.appID, $1.metric, $1.appName, $1.value) }
        var header: String
        var lines: [String] = []
        switch kind {
        case .appTime:
            header = "app_id,app_name,active_seconds,share_percent"
            let active = valid.filter { $0.metric == "active.seconds" }
            let groups = Dictionary(grouping: active, by: \.appID)
            let totals = groups.mapValues { $0.reduce(0) { $0 + $1.value } }
            let total = totals.values.sorted().reduce(0, +)
            for id in groups.keys.sorted(by: {
                totals[$0] == totals[$1] ? $0 < $1 : totals[$0]! > totals[$1]!
            }) {
                let seconds = totals[id]!
                lines.append([quote(id), quote(groups[id]!.last!.appName), number(seconds),
                              number(total > 0 ? seconds / total * 100 : 0)].joined(separator: ","))
            }
        case .input:
            header = "date,app_id,app_name,metric,value,unit"
            let input = valid.filter { $0.metric.hasPrefix("key:") || $0.metric.hasPrefix("mouse.") }
            let groups = Dictionary(grouping: input) { InputKey(day: $0.day, appID: $0.appID, metric: $0.metric) }
            for key in groups.keys.sorted(by: { ($0.day, $0.appID, $0.metric) < ($1.day, $1.appID, $1.metric) }) {
                let values = groups[key]!
                lines.append([quote(key.day), quote(key.appID), quote(values.last!.appName),
                              quote(key.metric), number(values.reduce(0) { $0 + $1.value }), quote(unit(key.metric))]
                    .joined(separator: ","))
            }
        case .network:
            header = "date,metric,value,unit"
            let network = valid.filter { $0.metric == "network.download.bytes" || $0.metric == "network.upload.bytes" }
            let groups = Dictionary(grouping: network) { "\($0.day)\u{1F}\($0.metric)" }
            for key in groups.keys.sorted() {
                let values = groups[key]!
                guard let row = values.first else { continue }
                lines.append([quote(row.day), quote(row.metric), number(values.reduce(0) { $0 + $1.value }), "\"bytes\""]
                    .joined(separator: ","))
            }
        case .hourly:
            header = "hour_utc,collected_local_date,app_id,app_name,metric,value,unit"
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.formatOptions = [.withInternetDateTime]
            for row in valid {
                // Keep the absolute hour and original day, including DST repeated hours.
                lines.append([quote(formatter.string(from: row.hour)), quote(row.day), quote(row.appID),
                              quote(row.appName), quote(row.metric), number(row.value), quote(unit(row.metric))]
                    .joined(separator: ","))
            }
        }
        return "\u{FEFF}" + header + "\r\n" + lines.joined(separator: "\r\n")
    }

    private static func unit(_ metric: String) -> String {
        if metric.hasPrefix("key:") || metric == "shortcut" { return "count" }
        switch metric {
        case "active.seconds": return "seconds"
        case "mouse.left", "mouse.right", "mouse.other": return "clicks"
        case "mouse.distance": return "event_units"
        case "mouse.scroll.pixels": return "points"
        case "mouse.scroll.lines": return "lines"
        case "network.download.bytes", "network.upload.bytes": return "bytes"
        default: return "unknown"
        }
    }

    private static func number(_ value: Double) -> String { String(value) }

    private static func quote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formula = trimmed.first.map { "=+-@".contains($0) } ?? false
        let controlPrefix = value.first.map { "\t\r\n".contains($0) } ?? false
        let safe = formula || controlPrefix ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

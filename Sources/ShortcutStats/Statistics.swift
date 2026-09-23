import Foundation

struct AppActivityRanking: Identifiable {
    let id: String
    let name: String
    let seconds: Double
    let share: Double
}

struct AppFilterOption: Identifiable {
    let id: String
    let name: String
    let activeSeconds: Double
}

/// Presentation aggregates for an already date- and app-filtered range.
/// Legacy shortcut totals and hourly input totals overlap and must never be added together.
struct ActivitySummary {
    let keyPresses: Double
    let shortcutCount: Int
    let mouseClicks: Double
    let activeSeconds: Double
    let appRankings: [AppActivityRanking]

    init(rows: [HourMetric], records: [UsageRecord]) {
        let valid = rows.filter { $0.value.isFinite && $0.value > 0 }
        keyPresses = valid.filter { $0.metric.hasPrefix("key:") && $0.metric.count > 4 }
            .reduce(0) { $0 + $1.value }
        shortcutCount = records.reduce(0) { $0 + max(0, $1.count) }
        mouseClicks = valid.filter { ["mouse.left", "mouse.right", "mouse.other"].contains($0.metric) }
            .reduce(0) { $0 + $1.value }
        let active = valid.filter { $0.metric == "active.seconds" }
        let total = active.reduce(0) { $0 + $1.value }
        activeSeconds = total
        appRankings = Dictionary(grouping: active, by: \.appID).map { id, values in
            let seconds = values.reduce(0) { $0 + $1.value }
            let latest = values.max { ($0.hour, $0.appName) < ($1.hour, $1.appName) }
            let name = latest?.appName ?? id
            return AppActivityRanking(id: id, name: name.isEmpty ? id : name,
                                      seconds: seconds, share: total > 0 ? seconds / total : 0)
        }.sorted { $0.seconds == $1.seconds ? $0.id < $1.id : $0.seconds > $1.seconds }
    }

    static func keyRecords(from rows: [HourMetric]) -> [UsageRecord] {
        rows.compactMap { row in
            guard row.metric.hasPrefix("key:"), row.metric.count > 4,
                  row.value.isFinite, row.value >= 1, row.value < Double(Int.max) else { return nil }
            return UsageRecord(day: row.day, appID: row.appID, appName: row.appName,
                               shortcut: String(row.metric.dropFirst(4)), count: Int(row.value), modifierCounts: [:])
        }
    }
}

struct UsageRecord: Codable {
    var day: String
    var appID: String
    var appName: String
    var shortcut: String
    var count: Int
    var modifierCounts: [String: Int]? = nil

    var resolvedModifierCounts: [String: Int] {
        modifierCounts ?? Dictionary(uniqueKeysWithValues: Statistics.keys(in: shortcut)
            .filter { Statistics.modifierSymbols.contains($0) }.map { ("?" + $0, count) })
    }

    mutating func addOccurrence(modifiers: [String: Int]) {
        var totals = resolvedModifierCounts
        for (key, value) in modifiers { totals[key, default: 0] += value }
        modifierCounts = totals
        count += 1
    }
}

struct Ranking: Identifiable {
    var id: String { shortcut }
    var shortcut: String
    var count: Int
}

enum Statistics {
    static func appFilterOptions(records: [UsageRecord], rows: [HourMetric], from: String, through: String) -> [AppFilterOption] {
        var names: [String: String] = [:]
        for record in records where !record.appID.isEmpty { names[record.appID] = record.appName }
        for row in rows where !row.appID.isEmpty && row.appID != NetworkTracker.systemAppID {
            names[row.appID] = row.appName
        }

        var seconds: [String: Double] = [:]
        for row in rows where row.metric == "active.seconds" && row.day >= from && row.day <= through
            && row.value.isFinite && row.value > 0 && names[row.appID] != nil {
            seconds[row.appID, default: 0] += row.value
        }

        return names.map { id, name in
            AppFilterOption(id: id, name: name.isEmpty ? id : name, activeSeconds: seconds[id, default: 0])
        }.sorted { lhs, rhs in
            if lhs.activeSeconds != rhs.activeSeconds { return lhs.activeSeconds > rhs.activeSeconds }
            let order = lhs.name.localizedStandardCompare(rhs.name)
            return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
        }
    }

    static func rankings(_ records: [UsageRecord], since: String, appID: String) -> [Ranking] {
        var totals: [String: Int] = [:]
        for record in records where record.day >= since && (appID.isEmpty || record.appID == appID) {
            totals[record.shortcut, default: 0] += record.count
        }
        return totals.map { Ranking(shortcut: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.shortcut < $1.shortcut : $0.count > $1.count }
    }

    static func csv(_ records: [UsageRecord]) -> String {
        func quoted(_ value: String) -> String {
            // Prevent app names from being interpreted as spreadsheet formulas.
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: { value.hasPrefix($0) }) ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return "\u{FEFF}date,app_id,app_name,shortcut,count\r\n" + records
            .sorted { ($0.day, $0.appID, $0.shortcut) < ($1.day, $1.appID, $1.shortcut) }
            .map { [quoted($0.day), quoted($0.appID), quoted($0.appName), quoted($0.shortcut), String($0.count)].joined(separator: ",") }
            .joined(separator: "\r\n")
    }
}

struct DailyUsage: Identifiable {
    var id: String { day }
    let day: String
    let count: Int
}

extension Statistics {
    static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func filtered(_ records: [UsageRecord], from: String, through: String, appID: String,
                         search: String = "", hidden: Set<String> = []) -> [UsageRecord] {
        guard from <= through else { return [] }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return records.filter {
            $0.day >= from && $0.day <= through && (appID.isEmpty || $0.appID == appID)
            && !hidden.contains($0.shortcut)
            && (query.isEmpty || $0.shortcut.localizedCaseInsensitiveContains(query))
        }
    }

    static func daily(_ records: [UsageRecord], from: Date, through: Date, calendar: Calendar = .current) -> [DailyUsage] {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: through)
        guard start <= end else { return [] }
        let totals = Dictionary(grouping: records, by: \.day).mapValues { $0.reduce(0) { $0 + $1.count } }
        var result: [DailyUsage] = []
        var date = start
        while date <= end {
            let day = dayString(date, calendar: calendar)
            result.append(DailyUsage(day: day, count: totals[day, default: 0]))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date), next > date else { break }
            date = next
        }
        return result
    }

    static func keys(in shortcut: String) -> Set<String> {
        let modifiers = shortcut.prefix(while: { "⌃⌥⇧⌘".contains($0) })
        var keys = Set(modifiers.map(String.init))
        let main = String(shortcut.dropFirst(modifiers.count))
        if !main.isEmpty { keys.insert(main) }
        return keys
    }

    static let modifierSymbols: Set<String> = ["⌘", "⌥", "⌃", "⇧"]
    static let modifierKeys = Set(modifierSymbols.flatMap { symbol in ["L", "R", "?"].map { $0 + symbol } })

    // Device-dependent masks from Apple's IOKit/hidsystem/IOLLEvent.h.
    // Read each event independently: no held-key state survives a pause or tap restart.
    static func modifierCounts(flags: UInt64) -> [String: Int] {
        let masks: [(String, UInt64, UInt64, UInt64)] = [
            ("⌘", 1 << 20, 0x08, 0x10), ("⌥", 1 << 19, 0x20, 0x40),
            ("⌃", 1 << 18, 0x01, 0x2000), ("⇧", 1 << 17, 0x02, 0x04)
        ]
        var result: [String: Int] = [:]
        for (symbol, combined, left, right) in masks where flags & combined != 0 {
            if flags & left != 0 { result["L" + symbol] = 1 }
            if flags & right != 0 { result["R" + symbol] = 1 }
            if flags & (left | right) == 0 { result["?" + symbol] = 1 }
        }
        return result
    }

    static func records(_ records: [UsageRecord], forKey key: String) -> [UsageRecord] {
        records.compactMap { record in
            var weighted = record
            weighted.count = modifierKeys.contains(key) ? record.resolvedModifierCounts[key, default: 0]
                : (keys(in: record.shortcut).contains(key) ? record.count : 0)
            return weighted.count > 0 ? weighted : nil
        }
    }

    // Existing aggregates know each side's participation, but not intersections
    // between different modifier sides. Never infer those intersections.
    static func heatmapRecords(_ records: [UsageRecord], modifier: String?) -> [UsageRecord] {
        guard let modifier else { return records }
        return self.records(records, forKey: modifier).map { record in
            var result = record
            result.modifierCounts = [modifier: record.count]
            return result
        }
    }

    // Presentation grouping for the reference keyboard; not physical-key inference.
    static let heatmapAliases = ["音量降低": "F11", "音量增加": "F12"]

    static func heatmapTotals(_ records: [UsageRecord]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (key, count) in keyTotals(records) {
            result[heatmapAliases[key] ?? key, default: 0] += count
        }
        return result
    }

    static func heatmapDetails(_ records: [UsageRecord], key: String) -> [UsageRecord] {
        let names = Set([key] + heatmapAliases.filter { $0.value == key }.map(\.key))
        return records.filter { !keys(in: $0.shortcut).isDisjoint(with: names) }
    }

    static func keyTotals(_ records: [UsageRecord]) -> [String: Int] {
        var totals: [String: Int] = [:]
        for record in records {
            for key in keys(in: record.shortcut) where !modifierSymbols.contains(key) {
                totals[key, default: 0] += record.count
            }
            for (key, count) in record.resolvedModifierCounts { totals[key, default: 0] += count }
        }
        return totals
    }
}

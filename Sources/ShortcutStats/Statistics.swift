import Foundation

struct UsageRecord: Codable {
    var day: String
    var appID: String
    var appName: String
    var shortcut: String
    var count: Int
}

struct Ranking: Identifiable {
    var id: String { shortcut }
    var shortcut: String
    var count: Int
}

enum Statistics {
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

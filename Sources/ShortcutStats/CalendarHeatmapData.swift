import Foundation

enum CalendarHeatmapMetric: String, CaseIterable, Identifiable {
    case shortcuts
    case keys
    case mouseClicks
    case activeTime
    case networkTraffic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortcuts: "快捷键"
        case .keys: "主键"
        case .mouseClicks: "鼠标点击"
        case .activeTime: "活跃时长"
        case .networkTraffic: "网络流量"
        }
    }
}
struct CalendarHeatmapDay: Identifiable {
    let date: Date
    let day: String
    let isFuture: Bool

    var id: String { day }
}

struct CalendarHeatmapWeek: Identifiable {
    let days: [CalendarHeatmapDay]
    let monthLabel: String?

    var id: String { days.first?.day ?? "empty-week" }
}

/// Precomputes all daily series once so switching the visible metric does not
/// repeatedly filter and group every source row from a SwiftUI `body` pass.
struct CalendarHeatmapData {
    let weeks: [CalendarHeatmapWeek]
    let totals: [CalendarHeatmapMetric: [String: Double]]
    let maximums: [CalendarHeatmapMetric: Double]
    let calendar: Calendar

    init(records: [UsageRecord], rows: [HourMetric], through: Date = Date(), calendar: Calendar = .current) {
        let aggregated = Self.aggregate(records: records, rows: rows)
        self.calendar = calendar
        totals = aggregated

        let today = calendar.startOfDay(for: through)
        let currentMonth = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: today)) ?? today
        let requestedStart = calendar.date(byAdding: .month, value: -11, to: currentMonth) ?? currentMonth
        let firstDate = Self.startOfWeek(containing: requestedStart, calendar: calendar)
        let finalWeekStart = Self.startOfWeek(containing: today, calendar: calendar)

        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.timeZone = calendar.timeZone
        monthFormatter.locale = calendar.locale ?? Locale.current
        monthFormatter.setLocalizedDateFormatFromTemplate("MMM")

        var result: [CalendarHeatmapWeek] = []
        var weekStart = firstDate
        while weekStart <= finalWeekStart {
            var days: [CalendarHeatmapDay] = []
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                days.append(CalendarHeatmapDay(
                    date: date,
                    day: Self.dayString(date, calendar: calendar),
                    isFuture: date > today
                ))
            }
            let labelDate = days.first(where: { day in
                calendar.component(.day, from: day.date) == 1
            })?.date
            let isFirstWeek = result.isEmpty
            let label = labelDate.map { monthFormatter.string(from: $0) }
                ?? (isFirstWeek ? monthFormatter.string(from: requestedStart) : nil)
            result.append(CalendarHeatmapWeek(days: days, monthLabel: label))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart), next > weekStart else { break }
            weekStart = next
        }
        weeks = result
        let visibleDays = Set(result.flatMap(\.days).filter { !$0.isFuture }.map(\.day))
        maximums = Dictionary(uniqueKeysWithValues: CalendarHeatmapMetric.allCases.map { metric in
            let visibleValues = aggregated[metric, default: [:]].filter { visibleDays.contains($0.key) }.values
            return (metric, visibleValues.max() ?? 0)
        })
    }

    func value(on day: String, metric: CalendarHeatmapMetric) -> Double {
        totals[metric]?[day] ?? 0
    }

    static func aggregate(records: [UsageRecord], rows: [HourMetric]) -> [CalendarHeatmapMetric: [String: Double]] {
        var result = Dictionary(uniqueKeysWithValues: CalendarHeatmapMetric.allCases.map { ($0, [String: Double]()) })

        // Shortcut totals come from the legacy daily source of truth. The hourly
        // shortcut marker overlaps it and must never be added a second time.
        for record in records where record.count > 0 {
            result[.shortcuts, default: [:]][record.day, default: 0] += Double(record.count)
        }

        for row in rows where row.value.isFinite && row.value > 0 {
            let metric: CalendarHeatmapMetric?
            if row.metric.hasPrefix("key:") {
                metric = .keys
            } else if ["mouse.left", "mouse.right", "mouse.other"].contains(row.metric) {
                metric = .mouseClicks
            } else if row.metric == "active.seconds" {
                metric = .activeTime
            } else if row.metric.hasPrefix("network.") {
                metric = .networkTraffic
            } else {
                metric = nil
            }
            if let metric { result[metric, default: [:]][row.day, default: 0] += row.value }
        }
        return result
    }

    static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func heatOpacity(_ ratio: Double) -> Double {
        let clamped = min(1, max(0, ratio))
        return 0.10 + 0.80 * clamped * clamped
    }
}

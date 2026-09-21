import Foundation

func runCalendarHeatmapChecks() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    calendar.firstWeekday = 2
    let through = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
    let hour = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 1, minute: 30))!

    let records = [
        UsageRecord(day: "2026-11-01", appID: "a", appName: "A", shortcut: "⌘C", count: 4),
        UsageRecord(day: "2026-11-01", appID: "b", appName: "B", shortcut: "⌘V", count: 3),
        UsageRecord(day: "2020-01-01", appID: "a", appName: "A", shortcut: "⌘C", count: 999),
        UsageRecord(day: "2026-11-02", appID: "a", appName: "A", shortcut: "⌘C", count: -1)
    ]
    let rows = [
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "shortcut", value: 50),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "key:C", value: 6),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "mouse.left", value: 2),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "mouse.right", value: 1),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "mouse.distance", value: 500),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "active.seconds", value: 120),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "network.download.bytes", value: 1_024),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "network.upload.bytes", value: 512),
        HourMetric(hour: hour, day: "2026-11-01", appID: "a", appName: "A", metric: "key:X", value: .infinity)
    ]
    let data = CalendarHeatmapData(records: records, rows: rows, through: through, calendar: calendar)

    check(data.value(on: "2026-11-01", metric: .shortcuts) == 7, "日历快捷键只汇总每日记录，不重复加入小时shortcut")
    check(data.value(on: "2026-11-01", metric: .keys) == 6, "日历主键只汇总key指标，不用快捷键补算")
    check(data.value(on: "2026-11-01", metric: .mouseClicks) == 3, "日历鼠标只合并按钮点击，排除移动")
    check(data.value(on: "2026-11-01", metric: .activeTime) == 120, "日历活跃时长按日汇总")
    check(data.value(on: "2026-11-01", metric: .networkTraffic) == 1_536, "日历网络流量合并上下行指标")
    check(data.value(on: "2026-11-02", metric: .shortcuts) == 0, "日历忽略无效的负数记录")
    check(data.maximums[.networkTraffic] == 1_536, "日历色阶峰值按独立指标计算")
    check(data.maximums[.shortcuts] == 7, "日历色阶峰值排除当前十二个月范围外的旧数据")
    check(abs(CalendarHeatmapData.heatOpacity(0) - 0.10) < 0.000_001
          && abs(CalendarHeatmapData.heatOpacity(0.5) - 0.30) < 0.000_001
          && abs(CalendarHeatmapData.heatOpacity(1) - 0.90) < 0.000_001,
          "日历颜色使用10%到90%的Gamma曲线")

    check(data.weeks.allSatisfy { $0.days.count == 7 }, "日历热力图每列保持完整一周")
    check(data.weeks.flatMap(\.days).map(\.day).contains("2026-03-08"), "日历热力图按日历跨越夏令时日期")
    check(Set(data.weeks.flatMap(\.days).map(\.day)).count == data.weeks.count * 7, "夏令时切换不重复或遗漏日历日")
    let finalDays = data.weeks.last?.days ?? []
    check(finalDays.first(where: { $0.day == "2026-11-02" })?.isFuture == false, "截止当天仍可选择")
    check(finalDays.filter { $0.day > "2026-11-02" }.allSatisfy(\.isFuture), "截止日后的未来日期标记为不可显示")
    check(data.weeks.compactMap(\.monthLabel).count >= 12, "约十二个月范围提供月份标签")

    var sundayCalendar = calendar
    sundayCalendar.firstWeekday = 1
    let sunday = sundayCalendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
    check(CalendarHeatmapData.startOfWeek(containing: sunday, calendar: sundayCalendar) == sunday,
          "热力图遵循用户日历的一周起始日")
}

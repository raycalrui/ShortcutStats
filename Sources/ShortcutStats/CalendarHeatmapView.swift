import SwiftUI

struct CalendarHeatmapView: View {
    private let data: CalendarHeatmapData
    @Binding private var selectedDay: Date
    private let selectDay: (Date) -> Void
    @State private var metric = CalendarHeatmapMetric.shortcuts

    init(records: [UsageRecord], rows: [HourMetric], selectedDay: Binding<Date>, selectDay: @escaping (Date) -> Void) {
        var calendar = Calendar.current
        calendar.locale = AppLanguage.locale
        data = CalendarHeatmapData(records: records, rows: rows, calendar: calendar)
        _selectedDay = selectedDay
        self.selectDay = selectDay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("日历热力图").font(.title2.bold())
            Text("查看最近约 12 个月的每日活动强度。空白或零值可能表示当时尚未开启对应采集，不代表整天没有使用。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("指标", selection: $metric) {
                ForEach(CalendarHeatmapMetric.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 260, alignment: .leading)

            HStack(alignment: .top, spacing: 8) {
                weekdayLabels
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 4) {
                        ForEach(data.weeks) { week in
                            CalendarHeatmapWeekView(
                                week: week,
                                metric: metric,
                                maximum: data.maximums[metric] ?? 0,
                                selectedDay: selectedDay,
                                calendar: data.calendar,
                                value: { data.value(on: $0, metric: metric) },
                                select: select
                            )
                        }
                    }
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.visible)
            }
            legend
            Text(metricNote).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var weekdayLabels: some View {
        let symbols = data.calendar.veryShortWeekdaySymbols
        let ordered = (0..<7).map { symbols[(data.calendar.firstWeekday - 1 + $0) % symbols.count] }
        return VStack(spacing: 4) {
            Color.clear.frame(width: 22, height: 18)
            ForEach(Array(ordered.enumerated()), id: \.offset) { index, symbol in
                Text(index.isMultiple(of: 2) ? symbol : "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 13)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text("少")
            ForEach(0..<5, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step == 0 ? Color.secondary.opacity(0.10) : heatColor(ratio: Double(step) / 4))
                    .frame(width: 13, height: 13)
            }
            Text("多")
            Text(L10n.format("最高 %@", formatted(data.maximums[metric] ?? 0)))
                .padding(.leading, 6)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("颜色从浅到深，最高 %@", formatted(data.maximums[metric] ?? 0)))
    }

    private var metricNote: String {
        switch metric {
        case .shortcuts: L10n.string("快捷键使用取自每日记录，不与小时快捷键标记重复相加。")
        case .keys: L10n.string("主键只包含开启“全部主键”采集后的小时汇总，不用旧快捷键记录补算。")
        case .mouseClicks: L10n.string("鼠标点击包含左键、右键和其他按钮，不包含滚动或移动。")
        case .activeTime: L10n.string("活跃时长不包含空闲、锁屏、睡眠和暂停时段。")
        case .networkTraffic: L10n.string("网络流量仅显示开始采集后的数据；尚未启用或没有记录时显示为零。")
        }
    }

    private func select(_ day: CalendarHeatmapDay) {
        guard !day.isFuture else { return }
        selectedDay = day.date
        selectDay(day.date)
    }

    private func heatColor(ratio: Double) -> Color {
        Color.accentColor.opacity(CalendarHeatmapData.heatOpacity(ratio))
    }

    private func formatted(_ value: Double) -> String {
        switch metric {
        case .activeTime:
            let minutes = value / 60
            return minutes < 60
                ? L10n.format("%@ 分钟", minutes.formatted(.number.locale(AppLanguage.locale).precision(.fractionLength(0))))
                : L10n.format("%@ 小时", (minutes / 60).formatted(.number.locale(AppLanguage.locale).precision(.fractionLength(1))))
        case .networkTraffic:
            return L10n.byteCount(value)
        default:
            return L10n.format("%@ 次", value.formatted(.number.locale(AppLanguage.locale).precision(.fractionLength(0))))
        }
    }
}

private struct CalendarHeatmapWeekView: View {
    let week: CalendarHeatmapWeek
    let metric: CalendarHeatmapMetric
    let maximum: Double
    let selectedDay: Date
    let calendar: Calendar
    let value: (String) -> Double
    let select: (CalendarHeatmapDay) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Color.clear.frame(width: 13, height: 18)
                .overlay(alignment: .leading) {
                    if let label = week.monthLabel {
                        Text(label).font(.caption2).foregroundStyle(.secondary).fixedSize()
                    }
                }
            ForEach(week.days) { day in
                if day.isFuture {
                    Color.clear.frame(width: 13, height: 13)
                } else {
                    let count = value(day.day)
                    Button { select(day) } label: {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(count > 0 ? color(ratio: count / max(1, maximum)) : Color.secondary.opacity(0.10))
                            .overlay {
                                if calendar.isDate(day.date, inSameDayAs: selectedDay) {
                                    RoundedRectangle(cornerRadius: 2).stroke(Color.primary, lineWidth: 1.5)
                                }
                            }
                            .frame(width: 13, height: 13)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.format("%@：%@", day.day, display(count)))
                    .accessibilityLabel(L10n.format("%@，%@ %@", day.day, metric.title, display(count)))
                }
            }
        }
    }

    private func color(ratio: Double) -> Color {
        Color.accentColor.opacity(CalendarHeatmapData.heatOpacity(ratio))
    }

    private func display(_ value: Double) -> String {
        switch metric {
        case .activeTime:
            return L10n.format("%@ 分钟", (value / 60).formatted(.number.locale(AppLanguage.locale).precision(.fractionLength(1))))
        case .networkTraffic:
            return L10n.byteCount(value)
        default:
            return L10n.format("%@ 次", value.formatted(.number.locale(AppLanguage.locale).precision(.fractionLength(0))))
        }
    }
}

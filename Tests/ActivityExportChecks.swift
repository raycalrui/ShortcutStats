import Foundation

func runActivityExportChecks() {
    let base = Date(timeIntervalSince1970: 1_793_509_200)
    func row(_ metric: String, _ value: Double, hour: Double = 0, app: String = "a", name: String = "Alpha", day: String = "2026-11-01") -> HourMetric {
        HourMetric(hour: base.addingTimeInterval(hour * 3600), day: day, appID: app, appName: name, metric: metric, value: value)
    }
    let rows = [row("active.seconds", 60), row("active.seconds", 30, hour: 1),
                row("active.seconds", 30, app: "b", name: "Beta"), row("key:C", 2),
                row("key:C", 3, hour: 1), row("shortcut", 4), row("mouse.left", 2),
                row("mouse.distance", 12.5), row("mouse.scroll.pixels", 7), row("mouse.scroll.lines", 3)]
    let app = ActivityCSV.csv(rows: rows, kind: .appTime)
    check(app.contains("\"a\",\"Alpha\",90.0,75.0") && app.contains("\"b\",\"Beta\",30.0,25.0"),
          "应用 CSV 跨小时汇总秒数，占比分母只含活跃时长")
    let input = ActivityCSV.csv(rows: rows, kind: .input)
    check(input.contains("\"key:C\",5.0,\"count\"") && !input.contains("shortcut") && !input.contains("active.seconds"),
          "键鼠 CSV 按天应用指标聚合，不混加快捷键和时长")
    check(input.contains("\"mouse.left\",2.0,\"clicks\"") && input.contains("12.5,\"event_units\"") &&
          input.contains("7.0,\"points\"") && input.contains("3.0,\"lines\""), "鼠标 CSV 保持点击移动与两种滚动单位")
    let secondDay = ActivityCSV.csv(rows: [row("key:C", 2), row("key:C", 3, day: "2026-11-02")], kind: .input)
    check(secondDay.components(separatedBy: "\r\n").count == 3, "键鼠 CSV 不合并不同日期")
    let hours = ActivityCSV.csv(rows: [row("key:C", 2), row("key:C", 3, hour: 1)], kind: .hourly)
    let formatter = ISO8601DateFormatter()
    check(hours.contains(formatter.string(from: base)) && hours.contains(formatter.string(from: base.addingTimeInterval(3600))) &&
          hours.contains("\"2026-11-01\""), "小时 CSV 保留独立 UTC 小时和采集日期，不合并 DST 重复小时")
    let unsafe = ActivityCSV.csv(rows: [row("key:C", 1, app: "=1+1", name: "  @SUM(1,2)\n\"quoted\"")], kind: .input)
    check(unsafe.contains("\"'=1+1\"") && unsafe.contains("\"'  @SUM(1,2)\n\"\"quoted\"\"\""),
          "扩展 CSV 防护公式注入并正确转义逗号换行引号")
    for kind in ActivityCSVKind.allCases {
        let value = ActivityCSV.csv(rows: rows, kind: kind)
        check(value.hasPrefix("\u{FEFF}") && value.contains("\r\n") && value == ActivityCSV.csv(rows: rows.reversed(), kind: kind),
              "扩展 CSV 带 BOM、CRLF 且排序稳定：\(kind.title)")
        check(ActivityCSV.csv(rows: [], kind: kind).components(separatedBy: "\r\n").count == 2,
              "空范围 CSV 只有表头，不伪造历史数据：\(kind.title)")
    }
    let invalid = ActivityCSV.csv(rows: [row("key:C", .nan), row("key:C", .infinity), row("key:C", -1)], kind: .input)
    check(!invalid.contains("key:C"), "无效计数不进入 CSV")
}

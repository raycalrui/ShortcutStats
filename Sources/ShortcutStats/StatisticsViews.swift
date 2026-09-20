import SwiftUI
import Charts

struct RankingList: View {
    let ranking: [Ranking]
    let hide: (String) -> Void
    var body: some View {
        if ranking.isEmpty {
            ContentUnavailableView("没有匹配的组合键", systemImage: "magnifyingglass", description: Text("尝试调整日期、应用、搜索内容，或恢复已隐藏的项目。"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(ranking.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            Text(String(index + 1)).foregroundStyle(.secondary).frame(width: 30)
                            Text(entry.shortcut).font(.system(.body, design: .monospaced).bold()).frame(width: 130, alignment: .leading)
                            GeometryReader { geo in
                                Capsule().fill(Color.accentColor.opacity(0.65))
                                    .frame(width: max(3, geo.size.width * Double(entry.count) / Double(ranking.first?.count ?? 1)))
                            }.frame(height: 9)
                            Text(entry.count.formatted()).monospacedDigit().frame(width: 70, alignment: .trailing)
                            Button { hide(entry.shortcut) } label: { Image(systemName: "eye.slash") }
                                .buttonStyle(.borderless).help("隐藏 \(entry.shortcut)")
                                .accessibilityLabel("隐藏 \(entry.shortcut)")
                        }.padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}

struct UsageTrend: View {
    let records: [UsageRecord]
    let from: String
    let through: String
    @State private var selectedDay: String?
    private var series: [DailyUsage] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = .current
        f.dateFormat = "yyyy-MM-dd"
        guard let start = f.date(from: from), let end = f.date(from: through) else { return [] }
        return Statistics.daily(records, from: start, through: end)
    }
    var body: some View {
        let points = series
        VStack(alignment: .leading, spacing: 12) {
            Text("\(records.reduce(0) { $0 + $1.count }) 次快捷键使用 · \(points.count) 天").font(.title3.bold())
            Text("按日期与应用筛选，不受排行榜搜索或隐藏项影响。0 表示没有记录，不代表全天都在采集。")
                .font(.caption).foregroundStyle(.secondary)
            if records.isEmpty {
                ContentUnavailableView("此范围没有记录", systemImage: "chart.bar")
            } else {
                Chart(points) { point in
                    BarMark(x: .value("日期", point.day), y: .value("次数", point.count))
                        .foregroundStyle(Color.accentColor.gradient)
                        .accessibilityLabel(point.day).accessibilityValue("\(point.count) 次")
                }
                .chartXSelection(value: $selectedDay)
                .chartXAxis {
                    AxisMarks(values: points.enumerated().filter { $0.offset % max(1, points.count / 6) == 0 }.map { $0.element.day })
                }
                .frame(minHeight: 160, maxHeight: 260)
                if let point = points.first(where: { $0.day == selectedDay }) {
                    Text("\(point.day)：\(point.count) 次").monospacedDigit()
                } else { Text("点击图表查看某天，或在下面查看每日明细。").foregroundStyle(.secondary) }
            }
            List(points.reversed()) { point in
                HStack { Text(point.day); Spacer(); Text("\(point.count) 次").monospacedDigit() }
            }.frame(minHeight: 80)
        }.frame(maxHeight: .infinity)
    }
}

struct KeyboardHeatmap: View {
    let records: [UsageRecord]
    var ordinaryKeys = false
    @State private var selectedKey: String?
    @State private var selectedModifier: String?
    private struct Key: Identifiable {
        let id: String
        let label: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let tracked: Bool
    }
    // Key rectangles follow the supplied compact Mac keyboard reference (1922 × 764).
    // Keep the reference aspect ratio instead of stretching individual rows.
    private var keys: [Key] {
        var result: [Key] = []
        func row(_ labels: [String], _ edges: [CGFloat], y: CGFloat, height: CGFloat) {
            for (i, label) in labels.enumerated() {
                result.append(Key(id: "\(y)-\(i)", label: label, x: edges[i], y: y,
                                  width: edges[i + 1] - edges[i] - 12, height: height,
                                  tracked: !["Lock", "Caps Lock", "fn"].contains(label)))
            }
        }
        row(["Esc"] + (1...12).map { "F\($0)" } + ["Lock"],
            [24,158,293,428,563,698,833,968,1103,1238,1373,1508,1643,1778,1908], y: 32, height: 60)
        row(["`","1","2","3","4","5","6","7","8","9","0","-","=","⌫"],
            [24,141,273,405,537,669,801,933,1065,1197,1329,1461,1593,1725,1908], y: 105, height: 114)
        row(["Tab","Q","W","E","R","T","Y","U","I","O","P","[","]","\\"],
            [24,207,339,471,603,735,867,999,1131,1263,1395,1527,1659,1791,1908], y: 234, height: 114)
        row(["Caps Lock","A","S","D","F","G","H","J","K","L",";","'","Return"],
            [24,240,372,504,636,768,900,1032,1164,1296,1428,1560,1692,1908], y: 363, height: 114)
        row(["⇧","Z","X","C","V","B","N","M",",",".","/","⇧"],
            [24,306,438,570,702,834,966,1098,1230,1362,1494,1626,1908], y: 492, height: 114)
        row(["fn","⌃","⌥","⌘","Space","⌘","⌥"],
            [24,156,288,420,570,1230,1380,1512], y: 620, height: 114)
        for (label, x, y) in [("←",1512.0,677.0),("↓",1644.0,681.0),("→",1776.0,677.0),("↑",1644.0,620.0)] {
            result.append(Key(id: label, label: label, x: x, y: y, width: 120, height: 53, tracked: true))
        }
        return result
    }
    private let functionIcons = ["F1":"sun.min", "F2":"sun.max", "F3":"rectangle.3.group", "F4":"magnifyingglass",
                                 "F5":"mic", "F6":"moon", "F7":"backward.end", "F8":"playpause", "F9":"forward.end",
                                 "F10":"speaker.slash", "F11":"speaker.wave.1", "F12":"speaker.wave.3", "Lock":"lock", "fn":"globe"]
    private let shifted = ["`":"~", "1":"!", "2":"@", "3":"#", "4":"$", "5":"%", "6":"^", "7":"&", "8":"*", "9":"(", "0":")", "-":"_", "=":"+", "[":"{", "]":"}", "\\":"|", ";":":", "'":"\"", ",":"<", ".":">", "/":"?"]

    @ViewBuilder private func legend(_ label: String, scale: CGFloat) -> some View {
        if let symbol = functionIcons[label] {
            Image(systemName: symbol).font(.system(size: 27 * scale))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let top = shifted[label] {
            VStack(spacing: 10 * scale) { Text(top); Text(label) }
                .font(.system(size: 32 * scale)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if ["⌃", "⌥", "⌘"].contains(label) {
            VStack(alignment: label == "⌃" ? .leading : .trailing, spacing: 18 * scale) {
                Text(label).font(.system(size: 30 * scale))
                Text(label == "⌃" ? "control" : label == "⌥" ? "option" : "cmd").font(.system(size: 24 * scale))
            }.padding(18 * scale).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if label == "Space" {
            Color.clear
        } else {
            let long = ["Tab", "Caps Lock", "Return", "⇧", "⌫", "Esc"].contains(label)
            let text = ["Tab":"tab", "Caps Lock":"caps lock", "Return":"return", "⇧":"shift", "⌫":"delete", "Esc":"esc"][label] ?? label
            Text(text).font(.system(size: (long ? 24 : 34) * scale))
                .padding(18 * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: long ? (label == "Return" || label == "⌫" ? .bottomTrailing : .bottomLeading) : .center)
        }
    }
    private func keyTitle(_ key: String) -> String {
        if !ordinaryKeys && key == "F11" { return "音量降低 / F11" }
        if !ordinaryKeys && key == "F12" { return "音量增加 / F12" }
        guard Statistics.modifierKeys.contains(key) else { return key }
        let side = key.hasPrefix("L") ? "左" : key.hasPrefix("R") ? "右" : "左右未知"
        return "\(key.dropFirst())（\(side)）"
    }
    private func recordKey(_ label: String) -> String {
        switch label { case "Tab": return "⇥"; case "Return": return "↩"; default: return label }
    }
    private func recordKey(_ key: Key) -> String {
        if Statistics.modifierSymbols.contains(key.label) {
            return (key.x < 960 ? "L" : "R") + key.label
        }
        return recordKey(key.label)
    }
    private func keyHelp(_ key: String, count: Int) -> String {
        if selectedModifier != nil && Statistics.modifierKeys.contains(key) && selectedModifier != key {
            return "\(keyTitle(key))：点击切换筛选"
        }
        return "\(keyTitle(key))：\(count) 次"
    }
    private func select(_ key: String) {
        if Statistics.modifierKeys.contains(key) {
            guard !ordinaryKeys else { return }
            selectedModifier = selectedModifier == key ? nil : key
            selectedKey = nil
        } else {
            selectedKey = key
        }
    }
    var body: some View {
        let filteredRecords = Statistics.heatmapRecords(records, modifier: selectedModifier)
        let totals = Statistics.heatmapTotals(filteredRecords)
        let modifiers = Statistics.modifierKeys
        let mainMaximum = totals.filter { !modifiers.contains($0.key) && !$0.key.hasPrefix("?") }.values.max() ?? 0
        let modifierMaximum = totals.filter { modifiers.contains($0.key) && !$0.key.hasPrefix("?") }.values.max() ?? 0
        let peak = max(1, mainMaximum)
        let extras = Set(totals.keys).union(Statistics.keyTotals(records).keys.filter { modifiers.contains($0) }).filter { !$0.hasPrefix("?") && !keys.filter(\.tracked).map { recordKey($0) }.contains($0) }.sorted()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ordinaryKeys ? "主键按下热力图" : "快捷键热力图").font(.title3.bold())
                Text(ordinaryKeys ? "物理主键按下次数，包含普通打字和快捷键；忽略长按重复。修饰键不单独统计。" : "统计快捷键中主键和修饰键的参与次数，不是全部打字量。左右修饰键独立统计；未提供左右信息的修饰键不显示，也不分配到两侧。顶部音量键合并展示音量操作与对应 F11/F12，点击查看各自明细；仅为展示分组，不代表事件来自该物理键。其他系统功能仍列在下方。Fn、Caps Lock 和锁定键不统计。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    if let modifier = selectedModifier {
                        Text("正在筛选：\(keyTitle(modifier))").font(.headline).foregroundStyle(.orange)
                        Button("取消筛选") { selectedModifier = nil; selectedKey = nil }
                    } else {
                        Text(ordinaryKeys ? "点击主键查看次数" : "点击修饰键筛选，再次点击取消").foregroundStyle(.secondary)
                    }
                }
                if selectedModifier != nil {
                    Text("主键颜色与明细仅显示包含此修饰键的记录。其他修饰键仅作筛选入口，不显示共同使用次数。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                GeometryReader { geometry in
                    let scale = geometry.size.width / 1922
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 20 * scale)
                            .fill(Color.secondary.opacity(0.12))
                        ForEach(keys) { key in
                            let name = recordKey(key)
                            let count = totals[name, default: 0]
                            let keyColor: Color = modifiers.contains(name) ? .orange : .blue
                            let colorPeak = modifiers.contains(name) ? max(1, modifierMaximum) : peak
                            Button { if key.tracked { select(name) } } label: {
                                legend(key.label, scale: scale)
                                    .foregroundStyle(key.tracked ? Color.primary : Color.secondary)
                                    .frame(width: key.width * scale, height: key.height * scale)
                                    .background(count > 0 && key.tracked ? keyColor.opacity(heatOpacity(Double(count) / Double(colorPeak))) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12 * scale))
                                    .overlay(RoundedRectangle(cornerRadius: 12 * scale).stroke((selectedKey == name || selectedModifier == name) && key.tracked ? keyColor : Color.secondary.opacity(0.25)))
                            }
                            .buttonStyle(.plain).disabled(!key.tracked || (ordinaryKeys && modifiers.contains(name)))
                            .help(key.tracked ? keyHelp(name, count: count) : "\(key.label)：不单独统计")
                            .accessibilityLabel(key.tracked ? keyHelp(name, count: count) : "\(key.label)，不单独统计")
                            .offset(x: key.x * scale, y: key.y * scale)
                        }
                    }
                }.aspectRatio(1922.0 / 764.0, contentMode: .fit)
                VStack(alignment: .leading, spacing: 6) {
                    colorLegend("主键", color: .blue, maximum: mainMaximum)
                    if !ordinaryKeys { colorLegend("修饰键", color: .orange, maximum: modifierMaximum) }
                    Text(ordinaryKeys ? "浅色使用较少，深色使用较多。" : "两组独立色阶：浅色使用较少，深色使用较多；跨组深浅不代表相同次数。")
                }.font(.caption).foregroundStyle(.secondary)
                if let key = selectedKey {
                    Text("\(keyTitle(key))：\(totals[key, default: 0]) 次").font(.headline)
                    ForEach(Statistics.rankings(Statistics.heatmapDetails(filteredRecords, key: key), since: "", appID: "")) { item in
                        HStack { Text(item.shortcut); Spacer(); Text("\(item.count) 次") }
                    }
                }
                if !extras.isEmpty {
                    Text("其他键位与系统功能").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) {
                        ForEach(extras, id: \.self) { key in keycap(key, label: keyTitle(key), count: totals[key, default: 0], peak: modifiers.contains(key) ? max(1, totals.filter { modifiers.contains($0.key) && !$0.key.hasPrefix("?") }.values.max() ?? 0) : peak) }
                    }
                }
                if filteredRecords.isEmpty { Text(selectedModifier == nil ? (ordinaryKeys ? "此范围没有主键记录。" : "此范围没有快捷键记录。") : "此范围没有使用该侧修饰键的记录。").foregroundStyle(.secondary) }
            }.padding(.vertical, 8)
        }.frame(maxHeight: .infinity)
    }
    private func heatOpacity(_ ratio: Double) -> Double {
        let clamped = min(1, max(0, ratio))
        return 0.10 + 0.80 * clamped * clamped
    }
    private func colorLegend(_ title: String, color: Color, maximum: Int) -> some View {
        HStack {
            Text(title).frame(width: 48, alignment: .leading)
            Rectangle().fill(LinearGradient(stops: (0...40).map { step in
                let position = Double(step) / 40
                return Gradient.Stop(color: color.opacity(heatOpacity(position)), location: CGFloat(position))
            }, startPoint: .leading, endPoint: .trailing))
                .frame(width: 110, height: 10)
            Text("最高 \(maximum) 次")
        }
    }
    private func keycap(_ key: String, label: String? = nil, count: Int, peak: Int, height: CGFloat = 36) -> some View {
        Button { select(key) } label: {
            Text(label ?? key).font(.system(size: 12, design: .monospaced).bold())
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .background((Statistics.modifierKeys.contains(key) ? Color.orange : Color.blue).opacity(count == 0 ? 0.05 : heatOpacity(Double(count) / Double(peak))), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke((selectedKey == key || selectedModifier == key) ? Color.blue : Color.secondary.opacity(0.3)))
        }.buttonStyle(.plain).help(keyHelp(key, count: count))
            .accessibilityLabel(keyHelp(key, count: count))
    }
}

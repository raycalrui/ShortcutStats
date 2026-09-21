import SwiftUI

struct DataManagementView: View {
    @ObservedObject var monitor: Monitor
    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var initializedDates = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("数据管理").font(.title2.bold())
                Spacer()
                Button("刷新") { monitor.refreshDataManagement() }
                Button("关闭") { dismiss() }
            }

            if let report = monitor.dataReport {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overview(report)
                        Divider()
                        storage(report)
                        Divider()
                        retention
                        Divider()
                        deletion
                    }
                }
            } else {
                ProgressView("正在读取数据概况…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let notice = monitor.dataManagementNotice {
                Text(notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if let error = monitor.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
        .padding(24)
        .frame(width: 650, height: 690)
        .onAppear { monitor.refreshDataManagement() }
        .onChange(of: monitor.dataReport) { _, report in initializeDates(report) }
    }

    private func overview(_ report: DataManagementReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("数据概况").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { Text("记录日期").foregroundStyle(.secondary); Text(dateRange(report)) }
                GridRow { Text("快捷键").foregroundStyle(.secondary); Text("\(report.shortcutRows) 条聚合记录 · \(report.shortcutUses) 次使用") }
                GridRow { Text("扩展小时数据").foregroundStyle(.secondary); Text("\(report.hourlyRows) 条聚合记录") }
                GridRow { Text("普通主键 / 鼠标点击").foregroundStyle(.secondary); Text("\(whole(report.ordinaryKeyPresses)) / \(whole(report.mouseClicks)) 次") }
                GridRow { Text("应用活跃时长").foregroundStyle(.secondary); Text(duration(report.activeSeconds)) }
                GridRow { Text("网络流量").foregroundStyle(.secondary); Text("下载 \(bytes(report.downloadBytes)) · 上传 \(bytes(report.uploadBytes))") }
                GridRow { Text("中断记录").foregroundStyle(.secondary); Text("\(report.interruptionRows) 条") }
            }
            Text("这里的数量是本机聚合记录，不包含输入正文、按键顺序、窗口标题或鼠标轨迹。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func storage(_ report: DataManagementReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("存储占用").font(.headline)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: report.totalBytes, countStyle: .file))
                    .font(.headline).monospacedDigit()
            }
            ForEach(report.files) { file in
                HStack {
                    Text(file.title)
                    Text(file.id).font(.caption).foregroundStyle(.tertiary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))
                        .foregroundStyle(.secondary).monospacedDigit()
                }.font(.callout)
            }
            if report.files.isEmpty { Text("当前没有已写入磁盘的统计文件。").foregroundStyle(.secondary) }
            Text("总计包含快捷键、中断、SQLite 主文件及 WAL/SHM，以及 Backups 文件夹中的安全备份。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var retention: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自动保留期限").font(.headline)
            Picker("保留统计数据", selection: Binding(
                get: { monitor.retentionDays },
                set: { monitor.configureRetention(days: $0) }
            )) {
                ForEach(DataRetention.allCases) { policy in Text(policy.title).tag(policy.rawValue) }
            }
            .frame(maxWidth: 260)
            Text("有限期限每天最多检查一次。发现过期数据时会先询问，确认后创建完整备份再删除；完成后保持暂停。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var deletion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("删除数据").font(.headline)
            HStack {
                DatePicker("从", selection: $startDate, displayedComponents: .date)
                DatePicker("到", selection: $endDate, displayedComponents: .date)
                Button("删除所选日期") { monitor.deleteData(from: startDate, through: endDate) }
                    .disabled(Calendar.current.startOfDay(for: startDate) > Calendar.current.startOfDay(for: endDate))
            }
            HStack {
                Button("清空快捷键统计") { monitor.clearShortcutData() }
                Button("清空扩展小时数据") { monitor.clearHourlyData() }
            }
            Text("按日期删除会同时移除范围内的快捷键、键鼠、应用时长、网络流量和与范围有交集的中断记录。单独清空只影响对应数据；采集开关、隐藏列表、更新和登录项设置不会删除。所有操作都需要再次确认。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func dateRange(_ report: DataManagementReport) -> String {
        guard let first = report.firstDay, let last = report.lastDay else { return "暂无记录" }
        return first == last ? first : "\(first) 至 \(last)"
    }

    private func whole(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(min(max(value, 0), Double(Int64.max))), countStyle: .file)
    }

    private func duration(_ seconds: Double) -> String {
        let value = Int(min(max(seconds, 0), Double(Int.max / 2)))
        if value < 60 { return "\(value) 秒" }
        let hours = value / 3600
        let minutes = value % 3600 / 60
        return hours == 0 ? "\(minutes) 分钟" : "\(hours) 小时 \(minutes) 分钟"
    }

    private func initializeDates(_ report: DataManagementReport?) {
        guard !initializedDates, let report else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let first = report.firstDay.flatMap(formatter.date(from:)) { startDate = first }
        if let last = report.lastDay.flatMap(formatter.date(from:)) { endDate = last }
        initializedDates = true
    }
}

import Charts
import SwiftUI

struct NetworkUsageView: View {
    let rows: [HourMetric]
    @AppStorage("metrics.network") private var enabled = false

    private var networkRows: [HourMetric] {
        rows.filter { $0.metric == "network.download.bytes" || $0.metric == "network.upload.bytes" }
    }
    private func total(_ metric: String) -> Double {
        networkRows.filter { $0.metric == metric }.reduce(0) { $0 + $1.value }
    }
    private var hourly: [NetworkHour] {
        Dictionary(grouping: networkRows, by: \.hour).map { hour, values in
            NetworkHour(hour: hour,
                        download: values.filter { $0.metric == "network.download.bytes" }.reduce(0) { $0 + $1.value },
                        upload: values.filter { $0.metric == "network.upload.bytes" }.reduce(0) { $0 + $1.value })
        }.sorted { $0.hour < $1.hour }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("网络流量").font(.title2.bold())
                    Spacer()
                    Toggle("统计整机网络流量", isOn: $enabled).toggleStyle(.switch)
                }
                Text(L10n.string(enabled ? "正在按活动网络接口累计上传与下载字节。" : "采集未开启；已有历史仍会显示，开启后开始累计。"))
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    networkCard("下载", bytes: total("network.download.bytes"), symbol: "arrow.down")
                    networkCard("上传", bytes: total("network.upload.bytes"), symbol: "arrow.up")
                    networkCard("合计", bytes: total("network.download.bytes") + total("network.upload.bytes"), symbol: "network")
                }
                Text("每小时趋势").font(.headline)
                if hourly.isEmpty {
                    ContentUnavailableView("暂无网络流量数据", systemImage: "network", description: Text("开启后使用网络即可开始累计。"))
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Chart(hourly) { item in
                        BarMark(x: .value(L10n.string("小时"), item.hour), y: .value(L10n.string("字节"), item.download))
                            .foregroundStyle(by: .value(L10n.string("方向"), L10n.string("下载")))
                        BarMark(x: .value(L10n.string("小时"), item.hour), y: .value(L10n.string("字节"), item.upload))
                            .foregroundStyle(by: .value(L10n.string("方向"), L10n.string("上传")))
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let bytes = value.as(Double.self) { Text(byteCount(bytes)) }
                            }
                        }
                    }
                        .frame(height: 240)
                }
                Text("记录整台 Mac 活动接口的字节增量，不记录 IP、域名、端口或数据内容，也不归因到具体 App。VPN、虚拟网卡或接口转发可能让同一流量被重复计算；睡眠、暂停及 App 未运行期间不补算。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }
    }

    private func networkCard(_ title: String, bytes: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.string(title), systemImage: symbol).foregroundStyle(.secondary)
            Text(byteCount(bytes)).font(.title2.bold()).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func byteCount(_ value: Double) -> String {
        L10n.byteCount(value)
    }
}

private struct NetworkHour: Identifiable {
    var id: Date { hour }
    let hour: Date
    let download: Double
    let upload: Double
}

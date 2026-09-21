import Foundation

func runNetworkMetricsChecks() {
    let previous = ["en0": NetworkInterfaceCounters(received: 100, sent: 50),
                    "utun0": NetworkInterfaceCounters(received: 20, sent: 10)]
    let current = ["en0": NetworkInterfaceCounters(received: 160, sent: 80),
                   "utun0": NetworkInterfaceCounters(received: 45, sent: 25),
                   "new": NetworkInterfaceCounters(received: 999, sent: 999)]
    let values = Dictionary(uniqueKeysWithValues: NetworkTracker.deltas(previous: previous, current: current).map { ($0.metric, $0.value) })
    check(values["network.download.bytes"] == 85 && values["network.upload.bytes"] == 45,
          "网络增量按已有活动接口汇总，新接口先建立基线")
    let reset = NetworkTracker.deltas(previous: previous,
        current: ["en0": NetworkInterfaceCounters(received: 1, sent: 1)])
    check(reset.isEmpty, "网卡计数回退不产生负数或巨大流量")
    check(NetworkTracker.deltas(previous: current, current: current).isEmpty, "无流量变化不写零值指标")
}

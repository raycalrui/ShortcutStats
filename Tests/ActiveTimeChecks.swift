import Foundation

func runActiveTimeChecks() {
    let tracker = ActiveTimeTracker()
    let base = Date(timeIntervalSince1970: 1_800_000_000)
    func sample(_ seconds: Double, app: String = "a", enabled: Bool = true,
                eligible: Bool = true, idle: Double = 0, wallOffset: Double = 0) -> [ActivitySlice] {
        tracker.sample(at: base.addingTimeInterval(seconds + wallOffset), uptime: seconds,
                       appID: app, appName: app.uppercased(), enabled: enabled,
                       eligible: eligible, idleSeconds: idle)
    }
    check(sample(0).isEmpty, "活跃时长首个采样只建立基线")
    let first = sample(2)
    check(first.count == 1 && first[0].end.timeIntervalSince(first[0].start) == 2,
          "活跃前台应用累计两个采样之间的时间")
    check(sample(4, enabled: false).isEmpty && sample(6).isEmpty,
          "暂停及恢复间隔不计入活跃时长")
    check(sample(8).count == 1, "恢复后的完整采样间隔正常计时")
    check(sample(10, eligible: false).isEmpty && sample(12).isEmpty,
          "锁屏或安全输入不可采集期间不计时")
    check(sample(30).isEmpty, "长时间采样中断不补计时")
    check(sample(32, wallOffset: 120).isEmpty, "墙上时钟跳变不计时")
    tracker.reset()
    _ = sample(0, idle: 59)
    let clipped = sample(2, idle: 61)
    check(clipped.count == 1 && clipped[0].end.timeIntervalSince(clipped[0].start) == 1,
          "空闲跨过六十秒阈值只累计阈值前时间")
    check(sample(4, idle: 63).isEmpty && sample(6, idle: 0).isEmpty,
          "空闲及空闲恢复首段不补计")
    check(sample(8).count == 1, "空闲恢复后继续计时")
    tracker.reset()
    _ = sample(0)
    let switched = sample(2, app: "b")
    check(switched.first?.appID == "a", "应用切换前的间隔归属旧应用")
    check(sample(4, app: "b").first?.appID == "b", "切换后的间隔归属新应用")
    tracker.reset()
    _ = sample(0)
    check(sample(2).first?.appID == "a" && sample(2, app: "b").isEmpty,
          "切换前结算及同时间更新应用不重复累计")
    check(sample(4, app: "b").first?.appID == "b", "同时间切换后基线正确")
    tracker.reset()
    check(sample(6).isEmpty, "重置丢弃未完成间隔")
    check(sample(8, idle: .nan).isEmpty && sample(10).isEmpty,
          "无效空闲值清除基线不污染后续时长")
    check(sample(9).isEmpty, "单调时钟回退不计时")
}

import CoreGraphics

func runInputMetricsChecks() {
    let key = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true)!
    key.flags = []
    check(InputMetrics.decode(key, keyboard: true, mouse: false).first?.metric == "key:C", "普通键使用物理键位计数")
    key.flags = [.maskCommand, .maskShift]
    check(InputMetrics.decode(key, keyboard: true, mouse: true).first?.value == 1, "快捷键也贡献一次全部按键统计")
    check(InputMetrics.decode(key, keyboard: false, mouse: true).isEmpty, "关闭按键选项不采集按键")
    key.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
    check(InputMetrics.decode(key, keyboard: true, mouse: true).isEmpty, "全部按键统计忽略自动重复")
    key.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
    key.type = .keyUp
    check(InputMetrics.decode(key, keyboard: true, mouse: true).isEmpty, "抬键不重复计数全部按键")
    key.type = .flagsChanged
    check(InputMetrics.decode(key, keyboard: true, mouse: true).isEmpty, "修饰键单独变化不纳入主键次数")
    let mouse = CGEvent(source: nil)!
    for (type, metric) in [(CGEventType.leftMouseDown, "mouse.left"), (.rightMouseDown, "mouse.right"), (.otherMouseDown, "mouse.other")] {
        mouse.type = type
        let delta = InputMetrics.decode(mouse, keyboard: false, mouse: true)
        check(delta.count == 1 && delta.first?.metric == metric && delta.first?.value == 1, "鼠标按钮按下独立计数 \(metric)")
        check(InputMetrics.decode(mouse, keyboard: true, mouse: false).isEmpty, "关闭鼠标选项不采集 \(metric)")
    }
    mouse.type = .leftMouseUp
    check(InputMetrics.decode(mouse, keyboard: true, mouse: true).isEmpty, "鼠标抬起不重复计数")
    for type in [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged] {
        mouse.type = type
        mouse.setIntegerValueField(.mouseEventDeltaX, value: -3)
        mouse.setIntegerValueField(.mouseEventDeltaY, value: 4)
        check(InputMetrics.decode(mouse, keyboard: false, mouse: true).first?.value == 5, "移动及拖动累计相对距离 \(type.rawValue)")
    }
    mouse.setIntegerValueField(.mouseEventDeltaX, value: 0)
    mouse.setIntegerValueField(.mouseEventDeltaY, value: 0)
    check(InputMetrics.decode(mouse, keyboard: false, mouse: true).isEmpty, "零移动不生成记录")
    mouse.type = .scrollWheel
    mouse.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
    mouse.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -3)
    mouse.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 2)
    mouse.setIntegerValueField(.scrollWheelEventDeltaAxis3, value: 1)
    var scroll = InputMetrics.decode(mouse, keyboard: false, mouse: true)
    check(scroll.first?.metric == "mouse.scroll.lines" && scroll.first?.value == 6, "离散滚动各轴绝对值按行累计")
    mouse.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    mouse.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -20)
    mouse.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 10)
    mouse.setIntegerValueField(.scrollWheelEventPointDeltaAxis3, value: 0)
    scroll = InputMetrics.decode(mouse, keyboard: false, mouse: true)
    check(scroll.first?.metric == "mouse.scroll.pixels" && scroll.first?.value == 30, "连续滚动使用点增量而非混用行增量")
    check(InputMetrics.eventMask & (CGEventMask(1) << CGEventType.otherMouseDragged.rawValue) != 0, "监听掩码覆盖其他按钮拖动")
    check(InputMetrics.eventMask & (CGEventMask(1) << CGEventType.keyUp.rawValue) == 0, "监听掩码不采集抬键")
}

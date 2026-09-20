import CoreGraphics
import Foundation

/// Decodes aggregate physical input only. Never reads Unicode text, cursor positions,
/// or event timestamps; modifier-only flagsChanged events are outside this counter.
enum InputMetrics {
    static let eventMask: CGEventMask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown,
        .otherMouseDown, .mouseMoved, .leftMouseDragged, .rightMouseDragged,
        .otherMouseDragged, .scrollWheel].reduce(0) { $0 | (CGEventMask(1) << $1.rawValue) }

    static func decode(_ event: CGEvent, keyboard: Bool, mouse: Bool) -> [MetricDelta] {
        if event.type == .keyDown {
            guard keyboard, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return [] }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let name = Monitor.keyNames[code] ?? "Key\(code)"
            return [MetricDelta(metric: "key:" + name, value: 1)]
        }
        guard mouse else { return [] }
        switch event.type {
        case .leftMouseDown: return [MetricDelta(metric: "mouse.left", value: 1)]
        case .rightMouseDown: return [MetricDelta(metric: "mouse.right", value: 1)]
        case .otherMouseDown: return [MetricDelta(metric: "mouse.other", value: 1)]
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            // Relative event units, not physical centimeters or stored pointer trajectories.
            let distance = hypot(event.getDoubleValueField(.mouseEventDeltaX),
                                 event.getDoubleValueField(.mouseEventDeltaY))
            return distance.isFinite && distance > 0 ? [MetricDelta(metric: "mouse.distance", value: distance)] : []
        case .scrollWheel:
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            let axes: [CGEventField] = continuous
                ? [.scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventPointDeltaAxis3]
                : [.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventDeltaAxis3]
            let amount = axes.reduce(0.0) { $0 + abs(event.getDoubleValueField($1)) }
            guard amount.isFinite, amount > 0 else { return [] }
            // Includes inertial scrolling and horizontal/third-axis motion; never mixes units.
            return [MetricDelta(metric: continuous ? "mouse.scroll.pixels" : "mouse.scroll.lines", value: amount)]
        default: return []
        }
    }
}

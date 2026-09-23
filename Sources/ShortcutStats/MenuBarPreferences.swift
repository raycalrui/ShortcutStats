import Foundation

enum StatusItemMetric: String, CaseIterable, Identifiable {
    case icon, shortcuts, mainKeys, mouseClicks, activeTime, networkDownload
    var id: String { rawValue }
    var title: String {
        switch self {
        case .icon: L10n.string("仅图标")
        case .shortcuts: L10n.string("今日快捷键")
        case .mainKeys: L10n.string("今日主键")
        case .mouseClicks: L10n.string("今日鼠标点击")
        case .activeTime: L10n.string("今日活跃时长")
        case .networkDownload: L10n.string("今日下载流量")
        }
    }
}

enum MenuBarDefaults {
    static func register() {
        UserDefaults.standard.register(defaults: [
            "quick.show.mainKeys": true,
            "quick.show.shortcuts": true,
            "quick.show.mouse": true,
            "quick.show.active": true,
            "quick.show.network": true,
            "quick.statusMetric": StatusItemMetric.icon.rawValue
        ])
    }
}

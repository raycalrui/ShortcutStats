import AppKit
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let preferenceKey = "app.language"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.string("跟随系统")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .system
    }

    static var locale: Locale {
        switch selected {
        case .english: Locale(identifier: "en")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .system: Locale.current
        }
    }

    func apply() {
        UserDefaults.standard.set(rawValue, forKey: Self.preferenceKey)
        switch self {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english, .simplifiedChinese:
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}

enum L10n {
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: AppLanguage.locale, arguments: arguments)
    }

    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return format("%d 秒", 0) }
        let whole = Int(min(seconds.rounded(.down), Double(Int.max / 2)))
        if whole < 60 { return whole == 0 ? string("不足 1 秒") : format("%d 秒", whole) }
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        if hours == 0 { return format("%d 分钟", minutes) }
        return minutes == 0 ? format("%d 小时", hours) : format("%d 小时 %d 分钟", hours, minutes)
    }

    static func byteCount(_ value: Double) -> String {
        Int64(min(max(value, 0), Double(Int64.max)))
            .formatted(.byteCount(style: .file).locale(AppLanguage.locale))
    }

    static func localizedShortcutName(_ storedName: String) -> String {
        let storedNames = [
            "音量增加", "音量降低", "亮度增加", "亮度降低", "静音", "播放/暂停",
            "下一首", "上一首", "快进", "快退", "键盘背光增加", "键盘背光降低", "键盘背光切换"
        ]
        return storedNames.contains(storedName) ? string(storedName) : storedName
    }

    static func localizedAppName(_ storedName: String) -> String {
        storedName == "整台 Mac" ? string("整台 Mac") : storedName
    }
}

extension Notification.Name {
    static let shortcutStatsLanguageDidChange = Notification.Name("ShortcutStatsLanguageDidChange")
}

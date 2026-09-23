import AppKit
import UniformTypeIdentifiers

extension Monitor {
    func exportActivityCSV(kind: ActivityCSVKind, from: String, through: String, appID: String) {
        do {
            // Network counters describe the whole Mac and are never attributed
            // to the foreground application selected in the dashboard.
            let exportAppID = kind == .network ? NetworkTracker.systemAppID : appID
            let rows = try activityRowsForExport(from: from, through: through, appID: exportAppID)
            let content = ActivityCSV.csv(rows: rows, kind: kind)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            let stem = (kind.filename as NSString).deletingPathExtension
            panel.nameFieldStringValue = "\(stem)-\(from)-\(through).csv"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch { errorMessage = L10n.format("导出失败：%@", error.localizedDescription) }
    }
}

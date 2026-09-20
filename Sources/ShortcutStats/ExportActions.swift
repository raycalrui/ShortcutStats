import AppKit
import UniformTypeIdentifiers

extension Monitor {
    func exportActivityCSV(kind: ActivityCSVKind, from: String, through: String, appID: String) {
        do {
            let rows = try activityRowsForExport(from: from, through: through, appID: appID)
            let content = ActivityCSV.csv(rows: rows, kind: kind)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            let stem = (kind.filename as NSString).deletingPathExtension
            panel.nameFieldStringValue = "\(stem)-\(from)-\(through).csv"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch { errorMessage = "导出失败：\(error.localizedDescription)" }
    }
}

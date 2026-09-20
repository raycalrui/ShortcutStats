import AppKit
import Combine
import Sparkle
import SwiftUI

/// Sparkle owns download verification, replacement and relaunch. Never install archives ourselves.
@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateController()
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var startupError: String?
    @Published private(set) var automaticallyChecksForUpdates = false
    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        // Local development identity must never be replaced by a public update.
        guard Bundle.main.bundleIdentifier == "cc.raycal.ShortcutStats" else {
            startupError = "本机开发版通过 Xcode 构建更新，不接收公开安装包。"
            return
        }
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$automaticallyChecksForUpdates)
        do {
            try controller.updater.start()
        } catch {
            startupError = "无法启动更新服务：\(error.localizedDescription)"
        }
    }

    var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard let controller else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    // The 0.x series is explicitly a preview; accept beta and stable feed entries.
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { ["beta"] }
}

struct UpdateSettings: View {
    @ObservedObject private var updater = UpdateController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("软件更新").font(.headline)
            HStack {
                Text("当前版本 \(updater.installedVersion)").foregroundStyle(.secondary)
                Spacer()
                Button("检查更新…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            Toggle("每天自动检查更新", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticChecks($0) }
            ))
            Text("当前接收预发布版和正式版。下载和安装前会征求确认，完成后重新启动 App。检查更新会连接 GitHub，不上传统计数据。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = updater.startupError {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
    }
}

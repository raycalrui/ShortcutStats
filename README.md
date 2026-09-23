# ShortcutStats

本地 Mac 快捷键频率统计工具，SwiftUI + Core Graphics，使用 Sparkle 提供签名更新。macOS 14 及以上。

A local-first Mac app that tracks keyboard shortcut usage, built with SwiftUI and Core Graphics. Sparkle is the only third-party dependency. Requires macOS 14 or later.

目前为早期版本，提供源码供自行构建，尚未提供经过公证的安装包。真实使用中的统计准确性及性能仍需进一步验证。

This is an early version distributed as source code for you to build. No notarized installer is available yet. Counting accuracy and performance in everyday use still need further validation.

## 功能 / Features

- 菜单栏后台运行，按使用次数排列快捷键。

  Runs in the background from the menu bar and ranks shortcuts by usage count.

- 按前台应用、今天、近 7 天、近 30 天或全部记录筛选。

  Filter by foreground app and time range: today, the last 7 days, the last 30 days, or all records.

- 暂停和恢复统计，导出当前筛选范围的 CSV。

  Pause and resume tracking, and export the current selection to CSV.

- 统计数据保存在本机，不保存输入正文，不上传数据。

  Statistics stay on your Mac. Typed text is not stored, and no data is uploaded.

- 应用详情与图标、日历热力图、整机网络流量、菜单栏摘要自定义，以及带安全备份的数据管理。

  App details and icons, a calendar heatmap, whole-Mac network traffic, customizable menu-bar summaries, and data management with safety backups.

## 构建与使用 / Build and usage

使用 Xcode 打开 `ShortcutStats.xcodeproj`，选择 **ShortcutStats → My Mac**，按 **⌘R** 编译运行。项目包含标准 macOS Application target、Debug / Release 配置和共享 Scheme；无需 Swift Package 或额外项目生成工具。

Open `ShortcutStats.xcodeproj` in Xcode, select **ShortcutStats → My Mac**, and press **⌘R** to build and run. The project includes a standard macOS application target, Debug and Release configurations, and a shared scheme. No Swift package or additional project generation tool is required.

默认使用本地 ad-hoc 签名，无需选择开发者团队。App 沿用原 Bundle ID 和统计数据路径。输入监控仍需在系统设置中授权；未启用 App Sandbox，保持原有全局监听及数据存储方式。

Local ad-hoc signing is used by default, so you do not need to select a development team. The app retains its original bundle identifier and statistics storage path. Input Monitoring permission must be granted in System Settings. App Sandbox is not enabled, preserving the existing global monitoring and data storage behavior.

命令行构建（需要完整 Xcode）：

Build from the command line (requires the full Xcode installation):

```sh
zsh scripts/build.sh
open dist/ShortcutStats.app
```

脚本优先使用 `DEVELOPER_DIR` 或已选中的完整 Xcode，否则寻找 `/Applications/Xcode-beta.app`、`/Applications/Xcode.app`；不会修改系统的 `xcode-select`。产物由 Xcode 构建后复制到 `dist`。

The scripts use `DEVELOPER_DIR` or the currently selected full Xcode installation first, then fall back to `/Applications/Xcode-beta.app` and `/Applications/Xcode.app`, in that order. They do not change the system-wide `xcode-select` setting. Xcode builds the app, which is then copied to `dist`.

点击「开始统计」，在系统设置 → 隐私与安全 → 输入监控中允许 ShortcutStats。必要时退出并重新打开。关闭窗口后通过菜单栏键盘图标再次打开，应用继续统计；「暂停统计」停止监听。

Click **开始统计** (Start Tracking), then allow ShortcutStats in **System Settings → Privacy & Security → Input Monitoring**. Quit and reopen the app if necessary. Closing the window leaves tracking active; click the keyboard icon in the menu bar to reopen it. **暂停统计** (Pause Tracking) stops monitoring.

权限未生效时，点击「开始统计」会显示操作提示，并等待权限生效后自动重试。若设置中已开启但仍无法启动，先退出重开；仍无效时，移除旧授权条目，通过「在 Finder 显示当前应用」找到实际运行的副本并重新添加。开发构建使用 ad-hoc 签名，重新构建后可能需要重新授权。

If permission is not effective, Start Tracking shows recovery instructions and automatically retries once access becomes available. If the switch is already enabled, quit and reopen first. If the issue persists, remove the old permission entry and use **在 Finder 显示当前应用** (Show Current App in Finder) to locate and re-add the running copy. Development builds use ad-hoc signing and may require renewed permission after rebuilding.

可筛选今天、近 7 天、近 30 天或全部记录，以及按键发生时的前台应用。CSV 导出遵循当前筛选条件，每行是日期、应用、组合键、次数，便于重新汇总。时间按 Mac 本地日历计算。

Filter records by today, the last 7 days, the last 30 days, or all time, and by the app that was in the foreground when a key was pressed. CSV exports respect the current filters. Each row contains the date, app, key combination, and count for further aggregation. Date ranges follow your Mac’s local calendar.

## 统计口径与边界 / Counting rules and limitations

- 记录包含 Command、Option 或 Control 的 key-down，也记录单独 F1–F20（键盘实际提供的键位）；Shift 可作为附加修饰键。常见音量、静音、亮度、播放和键盘背光事件也按单次按下统计。

  Counts key-down events containing Command, Option or Control, plus standalone F1–F20 where available. Shift can be an additional modifier. Recognized volume, mute, brightness, playback and keyboard-backlight events are also counted once per press.

- 不保存输入文字、按键顺序、窗口标题或网页地址。可选普通按键功能只保存键位汇总；统计数据不上网，检查更新会访问 GitHub。

  Text content, keystroke order, window titles and web addresses are not stored. Optional keyboard tracking stores aggregate physical-key counts only. Statistics are local; update checks access GitHub.

- 忽略系统自动重复。手动重复按键分别计数。

  System-generated key repeats are ignored. Separate manual presses are counted individually.

- 按键表示使用尝试，不确认命令是否执行成功；全局快捷键归属按键时的前台应用，并不一定是处理该快捷键的应用。

  A recorded key press represents an attempt, not confirmation that a command succeeded. Global shortcuts are attributed to the foreground app at the time of the press, which may differ from the app handling the shortcut.

- 当前键名按美式 QWERTY 物理键位标记；中文输入法下相同物理键仍合并。其他键盘布局暂不自动映射。

  Key labels currently use physical US QWERTY positions. The same physical keys are grouped together when using Chinese input methods. Other keyboard layouts are not automatically mapped yet.

- 默认不统计普通单键；开启全部主键统计后计入独立键位汇总，不进入快捷键排行榜。Fn 本身及多段快捷键语义暂不支持。搜索、听写、专注模式等系统操作若未产生可识别事件，不会计数。改键软件或宏生成的事件可能影响结果。

  Ordinary keys are excluded by default. Optional all-main-key tracking adds them to separate physical-key totals, not shortcut rankings. Fn itself and multi-step shortcut semantics remain unsupported. System actions such as Search, Dictation and Focus are not counted unless they emit a recognized event. Events generated by remapping tools or macros may affect the results.

- 安全输入启用时无法统计，并显示对应状态。应用未运行、休眠或未获权限期间没有数据。

  Tracking is unavailable while Secure Input is enabled, and the app displays that status. No data is collected while the app is not running, the Mac is asleep, or permission is missing.

- 每 15 秒原子保存统计，正常退出保存。强制退出或断电可能丢失最后约 15 秒数据。

  Statistics are saved atomically every 15 seconds and on normal exit. A forced quit or power loss may discard approximately the last 15 seconds of data.

- 数据路径：`~/Library/Application Support/ShortcutStats/statistics.json`。读取失败会停止记录，保护已有文件。

  Data is stored at `~/Library/Application Support/ShortcutStats/statistics.json`. If loading fails, tracking is disabled to protect the existing file.

- 本地 ad-hoc 签名供自用；重新构建可能需要重新授予输入监控权限。现已提供登录启动开关，尚未提供安装器。

  Local ad-hoc signing is intended for personal use. Rebuilding may require granting Input Monitoring permission again. A launch-at-login toggle is available; an installer is not yet provided.

## 验证 / Validation

现有逻辑检查通过独立脚本运行（不在 Xcode Test action 中）：

Run the logic checks using the standalone script (they are not part of the Xcode Test action):

```sh
zsh scripts/check.sh
```

手动验收：在 TextEdit 选中文本后按十次 ⌘C、十次 ⌘V，等待两秒核对次数；长按验证自动重复不累加；切换应用验证分类；暂停、退出重开验证停止监听及持久化；导出 CSV 核对筛选范围。权限开启前不能声称已完成真实键盘监听验证。

For manual validation, select text in TextEdit, press ⌘C ten times and ⌘V ten times, then wait two seconds and check the counts. Hold a key to confirm that automatic repeats do not increase the count. Switch apps to check attribution; pause tracking, quit, and reopen to check monitoring control and persistence. Export a CSV to verify the selected range. Live keyboard monitoring cannot be considered validated until permission has been granted and actual input has been tested.

## 反馈与贡献 / Feedback and contributions

欢迎通过 GitHub Issues 反馈问题，或提交 Pull Request。请说明 macOS / Xcode 版本、复现步骤及预期结果；分享日志或统计截图前，请移除个人信息。

Issues and pull requests are welcome. Please include your macOS and Xcode versions, steps to reproduce the problem, and the expected result. Remove personal information before sharing logs or screenshots of your statistics.

## 许可证 / License

本项目采用 [MIT License](LICENSE)。

This project is licensed under the [MIT License](LICENSE).


## 界面语言 / Interface language

ShortcutStats 提供英文和简体中文界面。默认「跟随系统」：简体中文系统显示中文，其他系统语言显示英文；也可以在主窗口底部打开「设置」，手动选择 English 或简体中文。语言偏好保存在本机，切换后 App 会先保存统计状态，再自动重新启动使菜单栏、主窗口、设置、权限说明和错误提示统一生效。

ShortcutStats includes English and Simplified Chinese interfaces. The default is **Follow System**: Simplified Chinese systems use Chinese, while all other system languages use English. You can also open **Settings** from the bottom of the main window and choose English or Simplified Chinese manually. The preference is stored locally. After a change, the app saves its tracking state and relaunches automatically so the menu bar, main window, settings, permission guidance, and error messages use the same language.


## 登录时启动 / Launch at login

在主窗口底部点击「设置」，开启「登录时启动 ShortcutStats」。如显示等待批准，点击「打开系统登录项设置」完成系统授权。关闭开关即可取消登录启动；设置中的状态以系统返回值为准，操作失败会显示错误。

Click **设置** (Settings) at the bottom of the main window and enable **登录时启动 ShortcutStats** (Launch ShortcutStats at login). If approval is required, use the button to open the system Login Items settings. Turn the toggle off to unregister. The displayed state reflects the system status, and failures are shown explicitly.

登录启动时只在菜单栏运行，不自动弹窗。手动打开 App 或点击菜单栏图标可显示窗口。手动暂停会跨重启保留；正常退出不会更改暂停偏好。缺少输入监控权限时，菜单栏显示警告图标，悬停可查看状态，打开窗口后可处理权限。

At login, the app runs in the menu bar without opening its main window. Open the app manually or click its menu bar icon to show the window. Manual pause persists across launches; quitting normally does not change that preference. Missing Input Monitoring permission produces a warning icon in the menu bar, with status available in its tooltip and permission guidance in the main window.

建议先将构建好的 App 放入应用程序文件夹，并退出其他副本，再从该位置开启登录启动。移动或重新构建 App 后可能需要重新设置登录项或输入监控权限。真实登录自动启动需通过注销再登录进行验证。

Place the built app in Applications and quit other copies before enabling launch at login from that location. Moving or rebuilding the app may require reconfiguring the login item or Input Monitoring permission. Actual login behavior must be verified by logging out and back in.


## 监听恢复与中断记录 / Monitoring recovery and interruption history

App 每约 2 秒检查采集条件和监听有效状态。睡眠、权限缺失或安全输入时停止监听；恢复后仅在用户希望继续统计时重新建立监听。创建失败最多每 5 秒重试一次，旧监听会先移除，避免重复计数。手动暂停始终优先，自动恢复不会取消暂停。

The app checks capture conditions and event-tap health approximately every two seconds. Monitoring stops during sleep, missing permission, or Secure Input, and resumes only when the user intends to keep tracking. Failed creation is retried at most once every five seconds. The previous tap is removed before replacement to prevent duplicate counting. Automatic recovery never overrides a manual pause.

主窗口和菜单栏区分正在统计、手动暂停、等待权限、安全输入、睡眠及监听异常。点击「中断记录」查看本 App 运行期间发现的中断起止时间和原因。记录单独原子保存至 `~/Library/Application Support/ShortcutStats/interruptions.json`，不包含按键、窗口或应用内容；原统计文件保持不变。

The main window and menu bar distinguish recording, manual pause, permission wait, Secure Input, sleep, and listener failure. Click **中断记录** (Interruption History) to view detected intervals and reasons. Records are saved atomically to `~/Library/Application Support/ShortcutStats/interruptions.json`, without keystrokes, window contents, or app contents. The original statistics file is unchanged.

检测有延迟，短暂中断可能未被发现。异常退出前未保存的记录可能丢失，无结束时间表示持续中或结束未知；App 未运行期间不会推算原因或补造记录。新增合成检查验证暂停优先级、恢复条件及中断记录生命周期，但真实睡眠唤醒、权限切换和安全输入仍需在本机验证。

Detection is delayed and brief interruptions may go unnoticed. Unsaved records can be lost on a crash; a missing end time means ongoing or unknown. No causes or records are inferred for periods when the app was not running. Added synthetic checks validate pause precedence, recovery conditions, and interruption lifecycle; actual sleep/wake, permission changes, and Secure Input still require on-device validation.


## 本地开发签名 / Local development signing

本机自用时，在下述本地配置中额外设置 `SHORTCUTSTATS_BUNDLE_ID = cc.raycal.ShortcutStats.local`，将开发版与公开安装版的权限身份分开。之后在 Xcode 选择 ShortcutStats → My Mac，使用 ⌘R 构建运行；不要在签名方式之间来回切换。本机开发版禁用公开更新，通过 Xcode 更新。首次切换需为开发版授权一次；它与公开版共用原统计数据目录，请勿同时运行两份应用。

For local use, also set `SHORTCUTSTATS_BUNDLE_ID = cc.raycal.ShortcutStats.local` in the local configuration below to separate development and public permission identities. Select ShortcutStats → My Mac in Xcode and use ⌘R; keep the signing configuration consistent. Local builds update through Xcode, with public updates disabled. Grant permission once when switching identities. Both variants share the existing statistics directory, so do not run them simultaneously.

Debug 和 Release 共用 `Configuration/Signing.xcconfig`，默认使用 ad-hoc 签名。需要固定开发身份时，可创建 Git 已忽略的 `Configuration/Signing.local.xcconfig`，设置 `DEVELOPMENT_TEAM` 和 `CODE_SIGN_IDENTITY` 为本机可用的开发团队与证书。不要提交该文件或私钥。证书更新后需同步本地配置。

Debug and Release share `Configuration/Signing.xcconfig`, with ad-hoc signing as the public default. For a stable development identity, create the Git-ignored `Configuration/Signing.local.xcconfig` and set `DEVELOPMENT_TEAM` and `CODE_SIGN_IDENTITY` to your locally available team and certificate. Do not commit this file or private keys. Update the local configuration when renewing the certificate.

从 ad-hoc 切换开发签名后，可能需要为当前 App 再授权一次输入监控。后续应使用同一 Bundle ID、签名身份和固定运行位置；是否保留授权仍需在本机重新构建后验证。

Switching from ad-hoc to development signing may require granting Input Monitoring permission again. Keep the same bundle identifier, signing identity, and launch location for subsequent builds. Permission persistence must still be verified after rebuilding on your Mac.


## 安装与应用内更新 / Installation and in-app updates

从 [Releases](https://github.com/raycalrui/ShortcutStats/releases) 下载 `.dmg`，打开后将 ShortcutStats 拖到 Applications，再从应用程序文件夹运行。macOS 14+，安装包包含 Apple Silicon 和 Intel 架构。请勿直接从 DMG 运行。当前为未经 Apple 公证的预发布版；首次打开被拦截时请参阅 [Apple 官方说明](https://support.apple.com/102445)。

Download the `.dmg` from [Releases](https://github.com/raycalrui/ShortcutStats/releases), open it and drag ShortcutStats into Applications. Launch it from Applications, not the mounted image. Requires macOS 14+; includes Apple Silicon and Intel binaries. This preview is not notarized by Apple; see [Apple's instructions](https://support.apple.com/102445) if the first launch is blocked.

点击主窗口或设置中的「检查更新…」，由 Sparkle 显示新版并在确认后下载、验证、安装和重启。设置中可开启每天自动检查，默认关闭；当前 0.x 版本接收预发布版和正式版。检查更新会请求 GitHub，联网方可看到常规连接信息（例如 IP 地址），但不上传快捷键统计。更新列表和安装包均验证 EdDSA 签名。

Click **检查更新…** (Check for Updates) in the dashboard or settings. Sparkle presents an available update and downloads, verifies, installs and relaunches after confirmation. Daily automatic checks are optional and off by default. The 0.x series accepts preview and stable releases. Checking contacts GitHub, which receives normal connection metadata such as your IP address, but no shortcut statistics. Both the feed and update archive are EdDSA-verified.

v0.1.0 尚未内置更新组件，因此需要手动安装一次 v0.1.1 或更高版本。替换签名或安装新版后可能需要重新授予输入监控权限；历史统计仍保留在原位置。

v0.1.0 does not include an updater, so install v0.1.1 or later manually once. Replacing a signed build or updating may require Input Monitoring permission again; historical statistics stay in their existing location.

### 发布维护 / Release maintenance

首次构建需要联网解析 Sparkle 2.10.0；依赖已通过 Package.resolved 锁定。公开 Developer ID 签名包按以下顺序准备（不要覆盖本地签名配置）：

The first build needs network access to resolve Sparkle 2.10.0, pinned in Package.resolved. Prepare a Developer ID signed public build as follows without modifying local signing configuration:

```sh
# 设置为本机 Developer ID Application 证书指纹（不含私钥）
export SHORTCUTSTATS_RELEASE_IDENTITY="YOUR_CERTIFICATE_SHA1"
zsh scripts/build-release.sh
zsh scripts/package-dmg.sh
zsh scripts/prepare-update.sh v0.1.1 dist/ShortcutStats-0.1.1.dmg .build/Xcode/SourcePackages/artifacts/sparkle/Sparkle/bin beta
```

每次发布先递增版本号和构建号。更新签名私钥仅存于钥匙串 account `cc.raycal.ShortcutStats`，保持备份安全，不能提交到 Git。先上传并验证 Release 安装包，再推送生成的 `appcast.xml`。不要手工修改已签名的更新列表；修改后必须重新签名。

Increment both the version and build number for each release. The update-signing private key lives only in the Keychain account `cc.raycal.ShortcutStats`; keep backups secure and never commit it. Upload and verify the release archive before pushing the generated `appcast.xml`. Do not edit a signed feed without re-signing it.


## 日期、排行榜与图表 / Dates, rankings and charts

时间菜单新增「自定义」，起止日期均包含在内，按 Mac 本地日期筛选；开始晚于结束时提示错误并禁止导出。排行榜搜索支持组合键文本（例如 ⌘C、Space），点击每行的隐藏按钮可隐藏项目；在「已隐藏」中逐条恢复或全部恢复。隐藏偏好重启后保留，原始统计不删除。

Choose Custom in the time menu for an inclusive date range using your Mac's local dates. Reversed ranges show an error and disable export. Search shortcut text such as ⌘C or Space, hide a row, and restore individual or all entries from Hidden. Hidden preferences persist across launches without deleting statistics.

CSV 菜单明确区分「日期与应用范围（全部组合键）」和「当前排行榜（含搜索与隐藏过滤）」。每日趋势及热力图只遵循日期和应用筛选，不受排行榜搜索、隐藏影响。每日趋势补齐范围内所有日期，支持点选和每日明细；0 表示无记录，不证明全天已完整采集。

The CSV menu distinguishes all shortcuts within the date/app range from the currently displayed ranking with search and hidden filters. Daily trends and the heatmap use only the date/app filters. Trends include every date with selection and daily details; zero means no records, not proof of complete capture.

热力图展示现有快捷键记录中的主键和修饰键参与频率，合并不同修饰组合，点击键位可查看次数及组合键明细。数字小键盘等额外键位单独列出。这不是全部键盘输入热力图，不统计普通打字，左右识别仅适用于新采集且包含设备左右标志的记录。

The heatmap aggregates main keys and modifiers from existing shortcut records across modifier combinations. Click a key for counts and shortcut details; additional keys such as the numeric keypad are listed separately. This is not an all-typing heatmap and only distinguishes sides for new events that provide device-side flags. Legacy records remain readable.


热力图主键为蓝色，修饰键为橙色，两组独立色阶。新记录根据每次事件的设备标志区分左右 ⌘、⌥、⌃、⇧；旧记录或缺少左右标志的输入仍在数据中保留未知计数，但热力图不显示未知项，也不推算两侧。两侧同时按住时各计一次参与，排行榜仍合并组合键。Fn、Caps Lock、锁定键不统计。可选 modifierCounts 字段保存每条聚合记录的左右及未知次数，旧数据兼容读取；CSV 仍导出合并后的组合键次数。

Main keys use blue and modifiers use orange with independent scales. New records use each event's device flags to distinguish left/right Command, Option, Control and Shift. Legacy records and events without side flags retain unknown counts internally; the heatmap hides them and never assigns them to either side. Holding both sides counts one participation per side; shortcut rankings remain merged. Fn, Caps Lock and Lock remain untracked. The optional modifierCounts field stores sided and unknown aggregate counts and supports legacy data. CSV continues to export merged shortcut counts.


主键使用蓝色、修饰键使用橙色，分别按各组最高次数计算颜色深浅；图例显示两组峰值，跨组同色不代表相同次数，原始计数不变。

Main keys use blue and modifiers use orange, with independent color scales based on each group's maximum. The legend shows both maxima; equal colors across groups do not imply equal counts. Raw counts are unchanged.

系统功能事件按名称独立排行；音量操作在热力图顶部对应音量键分组展示，其他系统功能列在下方。此分组不推断真实物理键位。事件只通过一个被动监听入口处理，忽略抬键和系统重复；真实键盘、改键软件及系统版本的兼容性需实测。

System-function events retain distinct ranking names. Volume actions are grouped on the top-row volume keys; other system functions appear below the keyboard. This grouping does not establish physical key origin. A single passive event tap handles delivery, ignoring releases and system repeats. Hardware, remapping tools and OS compatibility require real-device verification.

点击热力图中的左右修饰键可筛选主键用量，重复点击取消，点击另一修饰键切换。日期和应用范围继续生效，主键色阶与明细按筛选次数重新计算。包含额外修饰键的组合也计入。其他修饰键只作切换入口：已有聚合数据不能推算不同左右修饰键的共同使用次数。

Click a sided modifier to filter main-key usage; click it again to clear or another modifier to switch. Date and app filters still apply. Main-key colors and details use the filtered counts, including shortcuts with additional modifiers. Other modifiers serve as filter controls only: existing aggregates cannot establish co-occurrence between modifier sides.

音量增加/降低事件在热力图中分别与 F12/F11 合并展示，点击查看原始操作明细；排行榜和持久化数据不合并。这是参考键盘上的展示分组，不推断真实物理事件来源，修饰键筛选继续生效。

Volume Up/Down events are grouped with F12/F11 in the heatmap, with original actions retained in click-through details. Rankings and stored records remain separate. This is a presentation grouping for the reference keyboard, not an inference about the physical source; modifier filtering still applies.

热力图使用 Gamma＝2 的不透明度曲线：10% + 80% ×（次数 / 本组最高次数）²；零次键保持默认底色，主键和修饰键独立计算，图例采用相同曲线。

The heatmap uses a gamma-2 opacity curve: 10% + 80% × (count / group maximum)². Zero-count keys keep their default background. Main keys and modifiers use separate scales, and legends follow the same curve.

## 键鼠、应用时长与小时趋势 / Input, activity and hourly metrics

### 完整备份与恢复 / Complete backup and restore

主窗口底部「数据备份」可导出带版本号的 JSON，包含全部快捷键（含左右修饰键）、小时键鼠、活跃时长、网络流量和中断记录，也包含尚未写盘的汇总，不受当前筛选影响。备份包含应用使用历史，请自行妥善保存。采集开关、隐藏列表、登录启动和系统权限不在备份内。

Data Backup at the bottom of the dashboard exports versioned JSON containing all shortcuts (including modifier sides), hourly input/activity/network metrics and interruption history, including pending aggregates regardless of filters. Backups contain application usage history; store them appropriately. Collection preferences, hidden items, login settings and system permissions are excluded.

恢复前检查格式、版本、重复记录与数值，显示确认后替换全部统计，不相加。恢复前旧数据自动保存在 `~/Library/Application Support/ShortcutStats/Backups/`。失败会尝试回滚；意外退出时下次启动先处理恢复日志。完成后保持暂停，确认数据后手动开始。当前单个备份最大 256 MB；请勿同时运行多个应用副本。

Restore validates the format, version, duplicate records and values before confirmation, then replaces rather than adds to existing statistics. A pre-restore backup is saved in `~/Library/Application Support/ShortcutStats/Backups/`. Failures trigger rollback; interrupted restores are recovered at the next launch before collection. Restore leaves collection paused until you resume it. Each backup is limited to 256 MB; do not run multiple app copies simultaneously.

顶部左右箭头用于逐日查看：从今天向左依次查看昨天、前天，也可选择「按天查看」并直接选择日期；右箭头最多到今天，「回到今天」恢复今日范围。所有统计页面及 CSV 继续使用同一个日期和应用筛选。多日范围下左箭头从结束日向前一天开始。

Use the top arrows to browse individual days, or choose the daily mode and pick a date. Forward navigation stops at today; Return to Today restores today's range. All statistics pages and CSV exports share the date/app filters. From a multi-day range, the left arrow starts one day before its end date.

点击菜单栏图标可查看今日全部应用的快捷键、主键、鼠标点击、活跃时长和网络流量，并暂停／开始统计或打开主窗口。设置中可选择菜单栏图标旁显示快捷键、主键、鼠标、时长或下载量，并分别隐藏摘要卡片。该摘要独立于主窗口日期和应用筛选，未开启采集的指标会明确标注。

Click the menu-bar icon for today's all-app shortcut, main-key, mouse-click, active-time and network summary, with Pause/Start and Open Dashboard controls. Settings can show one selected metric beside the menu-bar icon and hide individual summary cards. This summary is independent of the dashboard filters and labels disabled collection explicitly.

「导出 CSV」提供应用活跃时长、键鼠每日统计、网络每日统计和每小时统计。时长单位为秒，应用占比为百分数；键鼠与网络保留各指标单位，小时记录同时保留 UTC 时间和采集时本地日期，不把旧每日快捷键推算为小时数据。网络统计属于整台 Mac，不受应用筛选影响。CSV 不是完整备份。

Export CSV also offers app active time, daily keyboard/mouse metrics, daily network metrics and hourly metrics. Durations use seconds and app shares use percentages; input and network metrics retain their units. Hourly exports preserve UTC timestamps and the captured local date, without inferring hours from legacy daily shortcuts. Network totals describe the whole Mac and ignore the app filter. CSV is not a complete backup.

「统计总览」为默认页面，按顶部日期与应用范围展示全部主键次数、快捷键次数、鼠标点击总数、活跃时长和活跃时长最高的应用。快捷键仍使用完整的每日历史，不与全部主键相加；其他指标仅包含开启采集后的记录。未开启的指标会明确提示，关闭采集不隐藏已有历史。

Overview is the default page. It shows main-key presses, shortcut uses, mouse clicks, active time and the most-used app by active time within the selected date/app range. Shortcut totals retain daily history and are not added to main-key totals. Other metrics only contain data collected after enabling them. Disabled collection is clearly labeled without hiding history.

「应用时长」提供独立排行榜，显示已安装应用的图标，按活跃时长降序排列，展示时长和占当前筛选范围总时长的比例。点击应用可查看该应用的活跃趋势、主键、快捷键和鼠标汇总以及常用快捷键 Top 10。支持顶部今天、近 7 天、近 30 天、全部和自定义日期；选择单个应用后占比以该筛选范围为准。它表示实际采集到的前台活跃时长，不是进程运行时间。

顶部应用筛选菜单也显示 App 图标，并按当前日期范围内的活跃时长降序排列；没有该范围时长记录的历史 App 保留在末尾。

App Time shows installed app icons and ranks apps by collected foreground active time. Click an app for its active-time trend, keyboard/shortcut/mouse totals and top 10 shortcuts. It supports Today, Last 7/30 Days, All and custom dates through the top filters. Selecting one app changes the share denominator accordingly. This measures observed active usage, not process uptime.

The app filter menu also shows app icons and sorts by active time in the current date range. Apps without active-time records in that range remain available at the end.

「日历热力图」按快捷键、主键、鼠标点击、活跃时长或网络流量展示最近约 12 个月的每日强度；点击日期会切换主窗口到该日。每种指标独立按可见峰值使用 10%–90%、Gamma＝2 的色阶。空白可能表示当时未开启采集，不代表全天为零。

Calendar Heatmap shows roughly the latest 12 months by shortcuts, main keys, mouse clicks, active time or network traffic. Clicking a date switches the dashboard to that day. Each metric uses its own visible maximum with a 10%–90%, gamma-2 scale. Empty cells can mean collection was disabled, not proven zero use.

「数据管理」显示记录日期范围、各类聚合数量、网络流量及统计文件和安全备份占用。可选择永久、最近 30/90/180/365 天保留，或按日期删除、分别清空快捷键和扩展小时数据。实际删除前必须再次确认并创建完整安全备份；失败回滚，完成后保持暂停。

Data Management shows the recorded date range, aggregate counts, network totals, statistics files and safety-backup storage. Choose permanent or 30/90/180/365-day retention, delete a date range, or clear shortcut and hourly data separately. Every actual deletion requires confirmation and a complete safety backup; failures roll back and collection remains paused afterward.

「网络流量」可选统计整台 Mac 活动网络接口的下载和上传字节，并显示每小时趋势。只保存字节增量，不记录 IP、域名、端口或数据内容，也不归因到具体 App。VPN、虚拟网卡或接口转发可能重复计算；暂停、睡眠及 App 未运行期间不补算。

Network Traffic optionally records downloaded and uploaded byte deltas for active interfaces across the whole Mac and shows an hourly trend. It stores no IP addresses, domains, ports or payload content and does not attribute traffic to apps. VPNs, virtual interfaces or forwarding can double-count; paused, sleeping and offline periods are never backfilled.

「键盘热力图」内可切换「快捷键」与「全部主键」，后者可直接开启采集，包含普通打字和快捷键的主键次数。切换模式清除选中的键位及修饰键筛选；全部主键模式不统计独立修饰键，顶部图标仅代表 F1–F12，不合并独立媒体事件。两种模式均保留原键盘布局与 Gamma 色阶，不推算旧数据。

Keyboard Heatmap switches between Shortcuts and All Main Keys, with a collection toggle for ordinary typing and shortcut main-key counts. Switching clears the selected key and modifier filter. All Main Keys excludes standalone modifiers; top-row icons represent F1–F12 without merging separate media events. Both modes retain the keyboard layout and gamma scale; historical data is never inferred.

在「统计总览」或对应页面可分别开启全部主键、鼠标、前台活跃时长和整机网络流量。四个开关默认关闭，重启后保留；关闭只停止新增，顶部暂停停止所有采集。日期和应用筛选共用，网络流量始终按整机显示。主键统计包括普通打字、Shift 组合及快捷键的物理主键，每次非自动重复 key-down 计一次，不保存文字或顺序，不单独累计修饰键按下；不与快捷键总数相加。

Overview and the corresponding pages independently enable all main keys, mouse metrics, foreground active time and whole-Mac network traffic. All four default off and persist across restarts. Disabling stops new collection but keeps history; the main Pause control stops all collection. Date and app filters are shared, while network totals remain system-wide. Main-key totals include ordinary typing, Shift combinations and shortcut main keys, excluding autorepeat. No text or sequence is stored; modifier-only presses are excluded. Do not add key totals to shortcut totals.

鼠标记录左/右/其他按钮按下次数、移动与拖动增量长度，以及绝对滚动量。移动使用事件单位，不代表厘米；连续滚动使用点（包括惯性），离散滚动使用行，累计所有轴，单位不混合。不保存位置或轨迹。

Mouse metrics count left/right/other button presses, movement/drag delta lengths and absolute scrolling across all axes. Movement uses event units, not centimeters. Continuous scrolling uses point deltas (including inertia); discrete scrolling uses lines. Units remain separate. Positions and trajectories are never stored.

应用活跃时长约每 2 秒采样，60 秒无输入视为空闲；暂停、锁屏、屏幕休眠、系统睡眠、安全输入及监听不可用期间不累计。恢复边界保守少计约一个采样间隔；这不是应用进程运行时长。按切换前应用结算，不补算 App 未运行的时间。

Foreground active time is sampled about every 2 seconds with a 60-second idle threshold. Pauses, locking, display/system sleep, Secure Input and unavailable monitoring prevent collection. Resume boundaries conservatively omit about one sampling interval. This estimates active usage, not process uptime, and never backfills time while ShortcutStats was not running.

新增汇总保存在 Application Support/ShortcutStats/activity.sqlite，按小时、应用和指标汇总，内存合并后每约 15 秒事务写入，正常退出保存。异常退出可能丢失最近一批。旧 statistics.json 保持原样继续用于快捷键每日历史，不进行破坏性迁移，也不推算旧的小时分布。小时使用绝对时间区分夏令时重复小时，日期筛选遵循采集时本地日期，图表以当前时区显示。空白时段可能未采集，不表示确实零使用。快捷键、应用时长、键鼠、网络和小时数据均可按各自 CSV 格式导出。

New aggregates live in Application Support/ShortcutStats/activity.sqlite, grouped by hour, app and metric. In-memory deltas are transactionally flushed about every 15 seconds and on normal exit; abnormal termination can lose the latest batch. Existing statistics.json remains the daily shortcut history with no destructive migration or inferred hourly history. Absolute hour timestamps distinguish repeated DST hours; date filtering uses the local date at capture and charts display the current time zone. Missing hours may be unobserved rather than zero usage. Shortcuts, app time, input, network and hourly data have separate CSV formats.

### 更新后权限身份 / Permission identity across updates

v0.3.0 及更早的公开包使用 ad-hoc 签名，身份绑定代码哈希，更新可能使旧输入监控授权失效。后续公开打包强制要求稳定的 Developer ID Application 签名；缺少证书时停止发布，不回退 ad-hoc。Sparkle EdDSA 签名不能代替 Apple 代码签名。旧身份首次迁移仍可能需要重新授权一次；稳定身份检查并不代替实际跨版本权限验收。公证仍需另外完成。

Public builds through v0.3.0 used ad-hoc signatures bound to code hashes, potentially invalidating Input Monitoring grants after updates. Future public packaging requires stable Developer ID Application signing and fails rather than falling back to ad-hoc. Sparkle EdDSA signatures do not replace Apple code signing. Initial migration may require one reauthorization; identity verification does not replace real upgrade permission testing. Notarization remains a separate step.

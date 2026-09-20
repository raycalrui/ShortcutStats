# AGENTS.md

本文件适用于整个 ShortcutStats 仓库，供参与开发的 agent 阅读。修改前先检查当前代码、README 和工作区状态；本文件描述的现状应以实际实现为准。

## 项目定位

- ShortcutStats 是本地运行的 macOS 菜单栏快捷键频率统计工具，使用 SwiftUI、AppKit 和 Core Graphics，除用于签名更新的 Sparkle 外不引入第三方依赖，最低支持 macOS 14。
- 保持标准 Xcode App 项目结构；不要改回 Swift Package，也不要为小改动引入项目生成工具或替换技术栈。
- 优先小范围、可验证的修改。诊断请求只提供发现与证据，除非用户同时要求修复。
- README 保持逐段中英对照；功能、使用方式或限制发生变化时，同步更新两种语言。

## 文件导航

| 路径 | 职责 |
| --- | --- |
| `Sources/ShortcutStats/ShortcutStatsApp.swift` | 应用入口、菜单栏、窗口生命周期和排行榜界面 |
| `Sources/ShortcutStats/Monitor.swift` | 输入监控权限、事件监听、应用归属、计数及本地保存 |
| `Sources/ShortcutStats/TrackingHealth.swift` | 状态判定、暂停优先级和中断记录模型 |
| `Sources/ShortcutStats/StatisticsViews.swift` | 排行榜组件、每日趋势及快捷键热力图 |
| `Sources/ShortcutStats/Statistics.swift` | 排名汇总、筛选和 CSV 编码 |
| `Configuration/Info.plist` | App 元数据与菜单栏应用配置 |
| `ShortcutStats.xcodeproj` | App target、构建配置和共享 Scheme |
| `Tests/main.swift` | 独立逻辑检查程序，不是 XCTest target |
| `scripts/build.sh` | 使用 Xcode 构建 Release，并复制到 `dist` |
| `scripts/check.sh` | 编译和运行逻辑检查 |
| `scripts/xcode-env.sh` | 为当前进程选择完整 Xcode |

新增 Swift 文件时，检查 Xcode target 的文件引用和 Sources build phase；独立检查程序所需的源文件还应加入 `scripts/check.sh`。

## 构建与验证

从仓库根目录运行：

```sh
# 逻辑检查
zsh scripts/check.sh

# Release 构建
zsh scripts/build.sh

# 检查生成的 App 签名
codesign --verify --strict --verbose=2 dist/ShortcutStats.app
```

- 在 Xcode 打开 `ShortcutStats.xcodeproj`，选择 `ShortcutStats → My Mac`，按 ⌘R 运行和调试。
- 构建需要完整 Xcode。脚本优先使用 `DEVELOPER_DIR` 或已选择的完整 Xcode，再寻找已安装的 Xcode；不要擅自修改全局 `xcode-select`。
- 公开默认使用 ad-hoc 签名；Debug / Release 共用 `Configuration/Signing.xcconfig`。个人签名身份仅放入已忽略的 `Configuration/Signing.local.xcconfig`，不得提交团队、证书、描述文件或凭据。
- 当前没有 Swift Package，也没有接入 Xcode Test action；不要用 `swift test` 或 `xcodebuild test` 代替现有检查脚本。
- 文档修改检查格式、链接和命令即可。统计逻辑修改运行相关逻辑检查；Swift、项目配置或界面修改还需构建验证，界面修改需检查实际窗口。
- 构建、逻辑检查通过不代表真实全局监听已验证。手动检查应覆盖计数、长按重复、应用切换、暂停、重启后的保存恢复及 CSV 筛选；报告清楚哪些已验证、哪些受权限或环境限制。
- 性能结论必须区分设计预期和实际测量；不要把编译成功写成低耗电或准确率已获验证。

## 统计与隐私约束

- 保持被动监听，不吞掉、重写或注入用户按键。
- 统计含 Command、Option 或 Control 的 key-down，以及独立 F1–F20 和白名单内的系统媒体/亮度事件，Shift 可作为附加修饰键；忽略系统自动重复，手动重复分别计数。
- 当前按美式 QWERTY 物理键位命名。普通单键、仅 Shift 普通组合、Fn 本身及多段快捷键语义不属于已支持范围。系统事件以功能名称保存，不推算物理 F 键位置；部分搜索/听写/专注模式可能没有可识别事件。
- 应用归属指按键时的前台应用，不等于实际处理快捷键的应用；计数代表按键尝试，不证明命令执行成功。
- 不保存输入正文、普通打字、按键顺序、窗口标题或网页地址，不添加遥测、统计数据上传或账号系统。检查更新仅访问 GitHub 上的签名更新列表和安装包。
- 不绕过输入监控权限或安全输入保护，不替用户重置权限数据库。安全输入期间的缺失不得伪装成完整统计。
- 事件回调保持轻量；避免逐次写盘、扫描菜单、执行耗时 I/O 或频繁刷新整个界面。
- 扩展统计范围时，先明确计数口径及对隐私、历史排名的影响，再实现并同步文档。

## 数据兼容性

- 中断记录独立保存在同目录的 `interruptions.json`，只保存起止时间及原因；不能把未知结束时间或未运行期间解释为完整采集。

- 保持 Bundle ID `cc.raycal.ShortcutStats` 和数据位置 `~/Library/Application Support/ShortcutStats/statistics.json`，除非任务明确要求变更。
- 保存记录包含日期、应用 ID、应用名、组合键和次数。日期遵循 Mac 本地日历，CSV 导出遵循当前筛选条件。
- 保留原子保存、正常退出保存以及读取失败时保护原文件的行为。不要为调试删除、覆盖或提交用户真实统计。
- 修改持久化格式时提供向后兼容方案；验证使用合成样本或隔离副本。
- CSV 编码须保留引号转义和公式注入防护。

## Git 与交付

- 修改前运行 `git status --short`，保留用户已有修改。只暂存当前任务涉及的文件，并检查 staged diff。
- 不提交 `.build/`、`dist/`、`.swiftpm/`、`xcuserdata/`、`*.xcuserstate`、个人统计、日志中的敏感内容或签名材料。
- 提交前运行 `git diff --cached --check`。推送必须在用户授权范围内，不能将一次发布授权视为所有未来发布的授权。
- 不擅自 force push、创建 Release、上传安装包或改变仓库可见性。
- 交付时简要说明改动、验证结果和未验证部分；区分本地修改、已提交与已确认推送。

## 发布与更新

- Sparkle 2.10.0 通过 Xcode Swift Package 依赖嵌入；保留 Package.resolved。更新组件负责签名验证、下载、替换和重启，不自行实现安装器。
- 更新列表和安装包均需 EdDSA 签名；不得关闭 `SURequireSignedFeed` 或 `SUVerifyUpdateBeforeExtraction`。
- 更新私钥在钥匙串的 `cc.raycal.ShortcutStats` account，不能导出或提交；Info.plist 只保存公钥。
- 每次发布递增 CFBundleVersion；0.x 接收 beta 和正式频道。自动检查默认关闭，用户可开启；安装必须确认。
- 构建 ad-hoc 公开包时使用命令行 `ENABLE_HARDENED_RUNTIME=NO CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`，之后运行 `scripts/sign-ad-hoc-release.sh`。本机开发签名及项目 hardened runtime 默认值保持原样。
- DMG 用 `scripts/package-dmg.sh` 生成；更新列表用 `scripts/prepare-update.sh` 生成。先上传对应 Release 附件并验证，再推送引用该附件的 appcast，避免用户收到失效下载。
- 不把 ad-hoc / EdDSA 更新签名等同于 Developer ID 或 Apple 公证。完整安装更新验收用隔离测试副本，避免替换用户正在使用的 App 或真实数据。

- 日期筛选包含起止日；排行榜搜索和隐藏只影响展示及明确标注的排行榜导出。趋势与热力图保持日期/应用范围的完整记录。隐藏项目保存在 UserDefaults，不改原始计数。热力图只代表键位参与快捷键的频率，不得称为全部打字热力图。


热力图主键为蓝色，修饰键为橙色，两组独立色阶。新记录根据每次事件的设备标志区分左右 ⌘、⌥、⌃、⇧；旧记录或缺少左右标志的输入仍在数据中保留未知计数，但热力图不显示未知项，也不推算两侧。两侧同时按住时各计一次参与，排行榜仍合并组合键。Fn、Caps Lock、锁定键不统计。可选 modifierCounts 字段保存每条聚合记录的左右及未知次数，旧数据兼容读取；CSV 仍导出合并后的组合键次数。

Main keys use blue and modifiers use orange with independent scales. New records use each event's device flags to distinguish left/right Command, Option, Control and Shift. Legacy records and events without side flags retain unknown counts internally; the heatmap hides them and never assigns them to either side. Holding both sides counts one participation per side; shortcut rankings remain merged. Fn, Caps Lock and Lock remain untracked. The optional modifierCounts field stores sided and unknown aggregate counts and supports legacy data. CSV continues to export merged shortcut counts.

音量增加/降低事件在热力图中分别与 F12/F11 合并展示，点击查看原始操作明细；排行榜和持久化数据不合并。这是参考键盘上的展示分组，不推断真实物理事件来源，修饰键筛选继续生效。

Volume Up/Down events are grouped with F12/F11 in the heatmap, with original actions retained in click-through details. Rankings and stored records remain separate. This is a presentation grouping for the reference keyboard, not an inference about the physical source; modifier filtering still applies.

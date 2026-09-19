# ShortcutStats

本地 Mac 快捷键频率统计工具，SwiftUI + Core Graphics，无第三方依赖。macOS 14 及以上。

A local-first Mac app that tracks keyboard shortcut usage, built with SwiftUI and Core Graphics. No third-party dependencies. Requires macOS 14 or later.

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

- 仅记录包含 Command、Option 或 Control 的 key-down；Shift 可作为附加修饰键。

  Only key-down events containing Command, Option, or Control are counted. Shift can be an additional modifier.

- 不保存普通输入、文字内容、按键顺序、窗口标题或网页地址，无网络请求。

  Ordinary typing, text content, keystroke order, window titles, and web addresses are not stored. The app makes no network requests.

- 忽略系统自动重复。手动重复按键分别计数。

  System-generated key repeats are ignored. Separate manual presses are counted individually.

- 按键表示使用尝试，不确认命令是否执行成功；全局快捷键归属按键时的前台应用，并不一定是处理该快捷键的应用。

  A recorded key press represents an attempt, not confirmation that a command succeeded. Global shortcuts are attributed to the foreground app at the time of the press, which may differ from the app handling the shortcut.

- 当前键名按美式 QWERTY 物理键位标记；中文输入法下相同物理键仍合并。其他键盘布局暂不自动映射。

  Key labels currently use physical US QWERTY positions. The same physical keys are grouped together when using Chinese input methods. Other keyboard layouts are not automatically mapped yet.

- 单键快捷键、仅 Shift 组合、媒体键、Fn 特殊操作、多段快捷键语义暂不支持。改键软件或宏生成的事件可能影响结果。

  Single-key shortcuts, Shift-only combinations, media keys, special Fn actions, and interpretation of multi-step shortcuts are not supported yet. Events generated by remapping tools or macros may affect the results.

- 安全输入启用时无法统计，并显示对应状态。应用未运行、休眠或未获权限期间没有数据。

  Tracking is unavailable while Secure Input is enabled, and the app displays that status. No data is collected while the app is not running, the Mac is asleep, or permission is missing.

- 每 15 秒原子保存统计，正常退出保存。强制退出或断电可能丢失最后约 15 秒数据。

  Statistics are saved atomically every 15 seconds and on normal exit. A forced quit or power loss may discard approximately the last 15 seconds of data.

- 数据路径：`~/Library/Application Support/ShortcutStats/statistics.json`。读取失败会停止记录，保护已有文件。

  Data is stored at `~/Library/Application Support/ShortcutStats/statistics.json`. If loading fails, tracking is disabled to protect the existing file.

- 本地 ad-hoc 签名供自用；重新构建可能需要重新授予输入监控权限。现已提供登录启动开关，尚未提供安装器。

  Local ad-hoc signing is intended for personal use. Rebuilding may require granting Input Monitoring permission again. A launch-at-login toggle is available; an installer is not yet provided.

## 验证 / Validation

现有 11 项逻辑检查通过独立脚本运行（不在 Xcode Test action 中）：

Run the 11 existing logic checks using the standalone script (they are not part of the Xcode Test action):

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


## 登录时启动 / Launch at login

在主窗口底部点击「设置」，开启「登录时启动 ShortcutStats」。如显示等待批准，点击「打开系统登录项设置」完成系统授权。关闭开关即可取消登录启动；设置中的状态以系统返回值为准，操作失败会显示错误。

Click **设置** (Settings) at the bottom of the main window and enable **登录时启动 ShortcutStats** (Launch ShortcutStats at login). If approval is required, use the button to open the system Login Items settings. Turn the toggle off to unregister. The displayed state reflects the system status, and failures are shown explicitly.

登录启动时只在菜单栏运行，不自动弹窗。手动打开 App 或点击菜单栏图标可显示窗口。手动暂停会跨重启保留；正常退出不会更改暂停偏好。缺少输入监控权限时，菜单栏显示警告图标，悬停可查看状态，打开窗口后可处理权限。

At login, the app runs in the menu bar without opening its main window. Open the app manually or click its menu bar icon to show the window. Manual pause persists across launches; quitting normally does not change that preference. Missing Input Monitoring permission produces a warning icon in the menu bar, with status available in its tooltip and permission guidance in the main window.

建议先将构建好的 App 放入应用程序文件夹，并退出其他副本，再从该位置开启登录启动。移动或重新构建 App 后可能需要重新设置登录项或输入监控权限。真实登录自动启动需通过注销再登录进行验证。

Place the built app in Applications and quit other copies before enabling launch at login from that location. Moving or rebuilding the app may require reconfiguring the login item or Input Monitoring permission. Actual login behavior must be verified by logging out and back in.

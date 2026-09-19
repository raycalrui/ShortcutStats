# ShortcutStats

本地 Mac 快捷键频率统计工具，SwiftUI + Core Graphics，无第三方依赖。macOS 14 及以上。

目前为早期版本，提供源码供自行构建，尚未提供经过公证的安装包。真实使用中的统计准确性及性能仍需进一步验证。

## 功能

- 菜单栏后台运行，按使用次数排列快捷键。
- 按前台应用、今天、近 7 天、近 30 天或全部记录筛选。
- 暂停和恢复统计，导出当前筛选范围的 CSV。
- 统计数据保存在本机，不保存输入正文，不上传数据。

## 构建与使用

使用 Xcode 打开 `ShortcutStats.xcodeproj`，选择 **ShortcutStats → My Mac**，按 **⌘R** 编译运行。项目包含标准 macOS Application target、Debug / Release 配置和共享 Scheme；无需 Swift Package 或额外项目生成工具。

默认使用本地 ad-hoc 签名，无需选择开发者团队。App 沿用原 Bundle ID 和统计数据路径。输入监控仍需在系统设置中授权；未启用 App Sandbox，保持原有全局监听及数据存储方式。

命令行构建（需要完整 Xcode）：

```sh
zsh scripts/build.sh
open dist/ShortcutStats.app
```

脚本优先使用 `DEVELOPER_DIR` 或已选中的完整 Xcode，否则寻找 `/Applications/Xcode-beta.app`、`/Applications/Xcode.app`；不会修改系统的 `xcode-select`。产物由 Xcode 构建后复制到 `dist`。

点击「开始统计」，在系统设置 → 隐私与安全 → 输入监控中允许 ShortcutStats。必要时退出并重新打开。关闭窗口后通过菜单栏键盘图标再次打开，应用继续统计；「暂停统计」停止监听。

可筛选今天、近 7 天、近 30 天或全部记录，以及按键发生时的前台应用。CSV 导出遵循当前筛选条件，每行是日期、应用、组合键、次数，便于重新汇总。时间按 Mac 本地日历计算。

## 统计口径与边界

- 仅记录包含 Command、Option 或 Control 的 key-down；Shift 可作为附加修饰键。
- 不保存普通输入、文字内容、按键顺序、窗口标题或网页地址，无网络请求。
- 忽略系统自动重复。手动重复按键分别计数。
- 按键表示使用尝试，不确认命令是否执行成功；全局快捷键归属按键时的前台应用，并不一定是处理该快捷键的应用。
- 当前键名按美式 QWERTY 物理键位标记；中文输入法下相同物理键仍合并。其他键盘布局暂不自动映射。
- 单键快捷键、仅 Shift 组合、媒体键、Fn 特殊操作、多段快捷键语义暂不支持。改键软件或宏生成的事件可能影响结果。
- 安全输入启用时无法统计，并显示对应状态。应用未运行、休眠或未获权限期间没有数据。
- 每 15 秒原子保存统计，正常退出保存。强制退出或断电可能丢失最后约 15 秒数据。
- 数据路径：`~/Library/Application Support/ShortcutStats/statistics.json`。读取失败会停止记录，保护已有文件。
- 本地 ad-hoc 签名供自用；重新构建可能需要重新授予输入监控权限。当前未提供开机启动或安装器。

## 验证

现有 11 项逻辑检查通过独立脚本运行（不在 Xcode Test action 中）：

```sh
zsh scripts/check.sh
```

手动验收：在 TextEdit 选中文本后按十次 ⌘C、十次 ⌘V，等待两秒核对次数；长按验证自动重复不累加；切换应用验证分类；暂停、退出重开验证停止监听及持久化；导出 CSV 核对筛选范围。权限开启前不能声称已完成真实键盘监听验证。

## 反馈与贡献

欢迎通过 GitHub Issues 反馈问题，或提交 Pull Request。请说明 macOS / Xcode 版本、复现步骤及预期结果；分享日志或统计截图前，请移除个人信息。

## 许可证

本项目采用 [MIT License](LICENSE)。

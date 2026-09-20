#!/bin/zsh
# Package a previously built app without changing its signing identity.
set -euo pipefail
cd "${0:A:h:h}"
app_path="${1:-$PWD/dist/ShortcutStats.app}"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Contents/Info.plist")
output_path="$PWD/dist/ShortcutStats-${version}.dmg"
zsh scripts/verify-release-signing.sh "$app_path"
[[ ! -e "$output_path" ]] || { echo "Refusing to replace $output_path" >&2; exit 1; }
stage_directory=$(mktemp -d "${TMPDIR:-/tmp}/shortcutstats-dmg.XXXXXX")
trap 'rm -rf "$stage_directory"' EXIT
ditto "$app_path" "$stage_directory/ShortcutStats.app"
ln -s /Applications "$stage_directory/Applications"
cat > "$stage_directory/安装说明 - Install.txt" <<'TEXT'
将 ShortcutStats 拖到 Applications，再从应用程序文件夹打开。
Drag ShortcutStats into Applications, then open it from Applications.

首次启动后授予输入监控权限。请勿直接从此磁盘映像运行。
Grant Input Monitoring permission on first launch. Do not run from this disk image.

此预发布版尚未经过 Apple 公证。系统拦截时请参阅：
This preview is not notarized by Apple. If macOS blocks it, see:
https://support.apple.com/102445
TEXT
hdiutil create -volname "ShortcutStats ${version}" -srcfolder "$stage_directory" -format UDZO "$output_path"
hdiutil verify "$output_path"
echo "$output_path"

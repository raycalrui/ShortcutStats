#!/bin/zsh
set -eu
cd "${0:A:h:h}"
source scripts/xcode-env.sh
xcodebuild -project ShortcutStats.xcodeproj -scheme ShortcutStats \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$PWD/.build/Xcode" build "$@"
mkdir -p dist
ditto .build/Xcode/Build/Products/Release/ShortcutStats.app dist/ShortcutStats.app
echo "$PWD/dist/ShortcutStats.app"

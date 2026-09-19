#!/bin/zsh
set -eu
cd "${0:A:h:h}"
source scripts/xcode-env.sh
mkdir -p .build/checks .build/ModuleCache
xcrun swiftc -module-cache-path "$PWD/.build/ModuleCache" \
  Sources/ShortcutStats/TrackingHealth.swift Sources/ShortcutStats/Statistics.swift Sources/ShortcutStats/Monitor.swift Tests/main.swift \
  -o .build/checks/statistics-check
.build/checks/statistics-check

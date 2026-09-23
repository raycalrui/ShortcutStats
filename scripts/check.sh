#!/bin/zsh
set -eu
cd "${0:A:h:h}"
source scripts/xcode-env.sh
mkdir -p .build/checks .build/ModuleCache
xcrun swiftc -module-cache-path "$PWD/.build/ModuleCache" \
  Sources/ShortcutStats/Localization.swift Sources/ShortcutStats/TrackingHealth.swift Sources/ShortcutStats/Statistics.swift Sources/ShortcutStats/Monitor.swift Sources/ShortcutStats/ActivityStore.swift Sources/ShortcutStats/InputMetrics.swift Sources/ShortcutStats/ActiveTimeTracker.swift Sources/ShortcutStats/NetworkMetrics.swift Sources/ShortcutStats/DataManagement.swift Sources/ShortcutStats/CalendarHeatmapData.swift Tests/InputMetricsChecks.swift Tests/ActiveTimeChecks.swift Tests/NetworkMetricsChecks.swift Tests/DataManagementChecks.swift Tests/CalendarHeatmapChecks.swift Sources/ShortcutStats/Backup.swift Sources/ShortcutStats/ActivityExport.swift Sources/ShortcutStats/DayNavigation.swift Tests/BackupChecks.swift Tests/ActivityExportChecks.swift Tests/main.swift \
  -o .build/checks/statistics-check
.build/checks/statistics-check

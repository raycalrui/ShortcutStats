#!/bin/zsh
# Validate the actual payload, not a different app left in dist/.
set -euo pipefail
archive="${1:?Usage: verify-update-archive.sh <dmg-or-zip>}"
project_directory="${0:A:h:h}"
work=$(mktemp -d "${TMPDIR:-/tmp}/shortcutstats-signcheck.XXXXXX")
mounted=0
cleanup() {
    if (( mounted )); then hdiutil detach "$work/mount" -quiet || return; fi
    rm -rf "$work"
}
trap cleanup EXIT
case "${archive:e:l}" in
    dmg)
        mkdir "$work/mount"
        hdiutil attach "$archive" -readonly -nobrowse -mountpoint "$work/mount" -quiet
        mounted=1
        payload="$work/mount/ShortcutStats.app"
        ;;
    zip)
        ditto -x -k "$archive" "$work/extracted"
        payload="$work/extracted/ShortcutStats.app"
        ;;
    *) echo 'Only DMG and ZIP update archives are supported.' >&2; exit 65 ;;
esac
[[ -d "$payload" ]] || { echo 'ShortcutStats.app is missing from archive root.' >&2; exit 65; }
zsh "$project_directory/scripts/verify-release-signing.sh" "$payload"

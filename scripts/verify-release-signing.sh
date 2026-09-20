#!/bin/zsh
# Reject hash-bound identities before packaging a public update.
set -euo pipefail
app_path="${1:?Usage: verify-release-signing.sh <app>}"
codesign --verify --deep --strict "$app_path"
signature_info=$(codesign -dv --verbose=4 "$app_path" 2>&1)
requirement=$(codesign -d -r- "$app_path" 2>&1)
if [[ "$signature_info" != *"Authority=Developer ID Application:"* || "$requirement" == *"cdhash "* ]]; then
    echo 'Release blocked: Developer ID Application signing with a stable designated requirement is required. Ad-hoc builds can lose Input Monitoring authorization on every update.' >&2
    exit 65
fi
if [[ "$signature_info" != *"Identifier=cc.raycal.ShortcutStats"* ]]; then
    echo 'Release blocked: unexpected bundle signing identifier.' >&2
    exit 65
fi
echo 'Release signing identity verified.'

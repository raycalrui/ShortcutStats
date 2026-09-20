#!/bin/zsh
# Certificate fingerprint is provided locally; never commit private signing material.
set -euo pipefail
cd "${0:A:h:h}"
identity="${SHORTCUTSTATS_RELEASE_IDENTITY:?Set SHORTCUTSTATS_RELEASE_IDENTITY to a Developer ID Application certificate SHA-1}"
identities=$(security find-identity -v -p codesigning)
if ! print -r -- "$identities" | /usr/bin/grep -F "$identity" | /usr/bin/grep -q 'Developer ID Application:'; then
    echo 'A valid Developer ID Application identity with its private key is required.' >&2
    exit 65
fi
zsh scripts/build.sh 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO SHORTCUTSTATS_BUNDLE_ID=cc.raycal.ShortcutStats "CODE_SIGN_IDENTITY=$identity" ENABLE_HARDENED_RUNTIME=YES
# Xcode may strip embedded framework headers; reseal inside out without downgrading identity.
codesign --force --sign "$identity" --timestamp --options runtime dist/ShortcutStats.app/Contents/Frameworks/Sparkle.framework
codesign --force --sign "$identity" --timestamp --options runtime --preserve-metadata=entitlements dist/ShortcutStats.app
zsh scripts/verify-release-signing.sh dist/ShortcutStats.app

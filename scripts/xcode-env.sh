# Select Xcode for this process only; do not change global xcode-select.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  selected_developer="$(xcode-select -p)"
  if [[ -x "$selected_developer/usr/bin/xcodebuild" && "$selected_developer" == *.app/Contents/Developer ]]; then
    export DEVELOPER_DIR="$selected_developer"
  elif [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    echo 'Please install Xcode or set DEVELOPER_DIR to its Contents/Developer directory.' >&2
    exit 1
  fi
fi

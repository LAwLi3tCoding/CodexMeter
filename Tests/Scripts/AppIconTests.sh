#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT_DIR/build/CodexMeter.app"
ICON_PATH="$APP_DIR/Contents/Resources/CodexMeter.icns"
EXTRACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-icon-tests.XXXXXX")/CodexMeter.iconset"

cleanup() {
  rm -rf "${EXTRACT_DIR:h}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

"$ROOT_DIR/scripts/build-app.sh" release >/dev/null

[[ -f "$ICON_PATH" ]] || fail "app bundle does not contain CodexMeter.icns"

icon_name="$(plutil -extract CFBundleIconFile raw -o - "$APP_DIR/Contents/Info.plist")"
[[ "$icon_name" == "CodexMeter" ]] || fail "CFBundleIconFile is not CodexMeter"

mkdir -p "$EXTRACT_DIR"
iconutil -c iconset "$ICON_PATH" -o "$EXTRACT_DIR"
[[ -f "$EXTRACT_DIR/icon_512x512@2x.png" ]] || fail "ICNS does not include a 1024px representation"

echo "PASS: app icon bundle"

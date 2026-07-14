#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 2
fi

cd "$ROOT_DIR"

SWIFT_BUILD_ARGUMENTS=(-c "$CONFIGURATION")
if [[ "${CODEXMETER_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGUMENTS+=(--disable-sandbox)
fi
if [[ -n "${CODEXMETER_SWIFT_SCRATCH_PATH:-}" ]]; then
  SWIFT_BUILD_ARGUMENTS+=(--scratch-path "$CODEXMETER_SWIFT_SCRATCH_PATH")
fi

swift build "${SWIFT_BUILD_ARGUMENTS[@]}" --product CodexMeter
swift build "${SWIFT_BUILD_ARGUMENTS[@]}" --product CodexMeterWidget \
  -Xswiftc -application-extension
BIN_DIR="$(swift build "${SWIFT_BUILD_ARGUMENTS[@]}" --show-bin-path)"
APP_DIR="$ROOT_DIR/build/CodexMeter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
WIDGET_DIR="$CONTENTS_DIR/PlugIns/CodexMeterWidget.appex"
WIDGET_CONTENTS_DIR="$WIDGET_DIR/Contents"
WIDGET_MACOS_DIR="$WIDGET_CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$WIDGET_MACOS_DIR"
install -m 755 "$BIN_DIR/CodexMeter" "$MACOS_DIR/CodexMeter"
install -m 644 "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
install -m 644 "$ROOT_DIR/Resources/CodexMeter.icns" "$RESOURCES_DIR/CodexMeter.icns"
install -m 644 "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"
install -m 755 "$BIN_DIR/CodexMeterWidget" "$WIDGET_MACOS_DIR/CodexMeterWidget"
install -m 644 "$ROOT_DIR/Resources/CodexMeterWidget-Info.plist" "$WIDGET_CONTENTS_DIR/Info.plist"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

if [[ "$CONFIGURATION" == "release" ]]; then
  strip -S "$MACOS_DIR/CodexMeter"
  strip -S "$WIDGET_MACOS_DIR/CodexMeterWidget"
fi

plutil -lint "$CONTENTS_DIR/Info.plist"
plutil -lint "$WIDGET_CONTENTS_DIR/Info.plist"
codesign \
  --force \
  --sign - \
  --timestamp=none \
  --entitlements "$ROOT_DIR/Resources/CodexMeterWidget.entitlements" \
  "$WIDGET_DIR"
codesign --verify --strict --verbose=2 "$WIDGET_DIR"
codesign \
  --force \
  --sign - \
  --timestamp=none \
  --entitlements "$ROOT_DIR/Resources/CodexMeter.entitlements" \
  "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built $APP_DIR"

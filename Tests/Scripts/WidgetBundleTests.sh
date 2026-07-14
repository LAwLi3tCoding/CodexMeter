#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT_DIR/build/CodexMeter.app"
APP_INFO="$APP_DIR/Contents/Info.plist"
BUNDLED_LICENSE="$APP_DIR/Contents/Resources/LICENSE"
WIDGET_DIR="$APP_DIR/Contents/PlugIns/CodexMeterWidget.appex"
WIDGET_INFO="$WIDGET_DIR/Contents/Info.plist"
WIDGET_EXECUTABLE="$WIDGET_DIR/Contents/MacOS/CodexMeterWidget"
APP_ENTITLEMENTS="$ROOT_DIR/Resources/CodexMeter.entitlements"
WIDGET_ENTITLEMENTS="$ROOT_DIR/Resources/CodexMeterWidget.entitlements"
WIDGET_SOURCE_INFO="$ROOT_DIR/Resources/CodexMeterWidget-Info.plist"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-widget-bundle-tests.XXXXXX")"
SIGNED_APP_ENTITLEMENTS="$TEST_ROOT/app-entitlements.plist"
SIGNED_WIDGET_ENTITLEMENTS="$TEST_ROOT/widget-entitlements.plist"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

plist_value() {
  plutil -extract "$2" raw -o - "$1" 2>/dev/null
}

[[ -f "$APP_ENTITLEMENTS" ]] || fail "missing app entitlements"
[[ -f "$WIDGET_ENTITLEMENTS" ]] || fail "missing widget entitlements"
[[ -f "$WIDGET_SOURCE_INFO" ]] || fail "missing widget Info.plist"

"$ROOT_DIR/scripts/build-app.sh" release >/dev/null

[[ -d "$WIDGET_DIR" ]] || fail "app bundle does not contain CodexMeterWidget.appex"
[[ -f "$BUNDLED_LICENSE" ]] || fail "app bundle does not contain LICENSE"
cmp -s "$ROOT_DIR/LICENSE" "$BUNDLED_LICENSE" || fail "bundled LICENSE differs from the project LICENSE"
[[ -f "$WIDGET_INFO" ]] || fail "widget bundle does not contain Info.plist"
[[ -x "$WIDGET_EXECUTABLE" ]] || fail "widget bundle does not contain an executable CodexMeterWidget"

[[ "$(plist_value "$WIDGET_INFO" CFBundlePackageType)" == "XPC!" ]] \
  || fail "widget CFBundlePackageType is not XPC!"
[[ "$(plist_value "$WIDGET_INFO" CFBundleExecutable)" == "CodexMeterWidget" ]] \
  || fail "widget CFBundleExecutable is not CodexMeterWidget"
[[ "$(plist_value "$WIDGET_INFO" CFBundleIdentifier)" == "com.codexmeter.CodexMeter.Widget" ]] \
  || fail "widget CFBundleIdentifier is invalid"
[[ "$(plist_value "$WIDGET_INFO" CFBundleShortVersionString)" == "0.1.0" ]] \
  || fail "widget short version is not 0.1.0"
[[ "$(plist_value "$WIDGET_INFO" CFBundleVersion)" == "1" ]] \
  || fail "widget build version is not 1"
[[ "$(plist_value "$WIDGET_INFO" LSMinimumSystemVersion)" == "13.0" ]] \
  || fail "widget minimum macOS version is not 13.0"
[[ "$(plist_value "$WIDGET_INFO" NSExtension.NSExtensionPointIdentifier)" == "com.apple.widgetkit-extension" ]] \
  || fail "widget extension point is invalid"
[[ "$(plist_value "$APP_INFO" NSHumanReadableCopyright)" == "Copyright © 2026 CodexMeter Contributors" ]] \
  || fail "app copyright metadata is missing"
[[ "$(plist_value "$WIDGET_INFO" NSHumanReadableCopyright)" == "Copyright © 2026 CodexMeter Contributors" ]] \
  || fail "widget copyright metadata is missing"

if plist_value "$APP_ENTITLEMENTS" 'com\.apple\.security\.app-sandbox' >/dev/null; then
  fail "app entitlement must not enable the app sandbox"
fi
[[ "$(plist_value "$WIDGET_ENTITLEMENTS" 'com\.apple\.security\.app-sandbox')" == "true" ]] \
  || fail "widget entitlement does not enable the app sandbox"
[[ "$(plist_value "$WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-only.0')" == "/Library/Application Support/CodexMeter/" ]] \
  || fail "widget entitlement does not restrict shared snapshot access to CodexMeter Application Support"
if plist_value "$WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-only.1' >/dev/null \
  || plist_value "$WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-write' >/dev/null \
  || plist_value "$WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.absolute-path\.read-only' >/dev/null \
  || plist_value "$WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.absolute-path\.read-write' >/dev/null \
  || plist_value "$WIDGET_ENTITLEMENTS" 'com\.apple\.security\.application-groups' >/dev/null; then
  fail "widget source entitlement expands shared-file access"
fi

codesign --verify --strict --verbose=2 "$WIDGET_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
codesign -d --entitlements :- "$APP_DIR" > "$SIGNED_APP_ENTITLEMENTS" 2>/dev/null
codesign -d --entitlements :- "$WIDGET_DIR" > "$SIGNED_WIDGET_ENTITLEMENTS" 2>/dev/null

if plist_value "$SIGNED_APP_ENTITLEMENTS" 'com\.apple\.security\.app-sandbox' >/dev/null; then
  fail "signed app must not enable the app sandbox"
fi
[[ "$(plist_value "$SIGNED_WIDGET_ENTITLEMENTS" 'com\.apple\.security\.app-sandbox')" == "true" ]] \
  || fail "signed widget does not enable the app sandbox"
[[ "$(plist_value "$SIGNED_WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-only.0')" == "/Library/Application Support/CodexMeter/" ]] \
  || fail "signed widget does not preserve its read-only snapshot exception"
if plist_value "$SIGNED_WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-only.1' >/dev/null \
  || plist_value "$SIGNED_WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-write' >/dev/null \
  || plist_value "$SIGNED_WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.absolute-path\.read-only' >/dev/null \
  || plist_value "$SIGNED_WIDGET_ENTITLEMENTS" 'com\.apple\.security\.temporary-exception\.files\.absolute-path\.read-write' >/dev/null \
  || plist_value "$SIGNED_WIDGET_ENTITLEMENTS" 'com\.apple\.security\.application-groups' >/dev/null; then
  fail "signed widget expands shared-file access"
fi

echo "PASS: widget extension bundle"

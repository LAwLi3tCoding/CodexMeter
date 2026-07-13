#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'EOF'
Create CodexMeter GitHub Release assets.

Usage:
  ./scripts/package-release.sh v0.1.0

Environment variables:
  CODEXMETER_APP_PATH     Package an existing CodexMeter.app instead of building it
  CODEXMETER_OUTPUT_DIR   Release asset directory (default: ./dist)
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 1 || ! "$1" =~ '^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' ]]; then
  usage >&2
  exit 2
fi

readonly RELEASE_TAG="$1"
readonly RELEASE_VERSION="${RELEASE_TAG#v}"
readonly OUTPUT_DIR="${CODEXMETER_OUTPUT_DIR:-$ROOT_DIR/dist}"

if [[ -n "${CODEXMETER_APP_PATH:-}" ]]; then
  readonly APP_DIR="$CODEXMETER_APP_PATH"
else
  "$ROOT_DIR/scripts/build-app.sh" release
  readonly APP_DIR="$ROOT_DIR/build/CodexMeter.app"
fi

readonly INFO_PLIST="$APP_DIR/Contents/Info.plist"
readonly EXECUTABLE="$APP_DIR/Contents/MacOS/CodexMeter"
readonly ICON_PATH="$APP_DIR/Contents/Resources/CodexMeter.icns"
readonly WIDGET_DIR="$APP_DIR/Contents/PlugIns/CodexMeterWidget.appex"
readonly WIDGET_INFO_PLIST="$WIDGET_DIR/Contents/Info.plist"
readonly WIDGET_EXECUTABLE="$WIDGET_DIR/Contents/MacOS/CodexMeterWidget"

if [[ ! -d "$APP_DIR" || ! -f "$INFO_PLIST" || ! -x "$EXECUTABLE" ]]; then
  echo "Invalid CodexMeter app bundle: $APP_DIR" >&2
  exit 1
fi

if [[ ! -f "$ICON_PATH" ]]; then
  echo "Missing app icon: $ICON_PATH" >&2
  exit 1
fi

if [[ ! -d "$WIDGET_DIR" || ! -f "$WIDGET_INFO_PLIST" || ! -x "$WIDGET_EXECUTABLE" ]]; then
  echo "Invalid CodexMeter widget bundle: $WIDGET_DIR" >&2
  exit 1
fi

WIDGET_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$WIDGET_INFO_PLIST" 2>/dev/null || true)"
if [[ "$WIDGET_BUNDLE_ID" != "com.codexmeter.CodexMeter.Widget" ]]; then
  echo "Invalid widget CFBundleIdentifier: ${WIDGET_BUNDLE_ID:-<missing>}." >&2
  exit 1
fi

WIDGET_EXTENSION_POINT="$(plutil -extract NSExtension.NSExtensionPointIdentifier raw -o - "$WIDGET_INFO_PLIST" 2>/dev/null || true)"
if [[ "$WIDGET_EXTENSION_POINT" != "com.apple.widgetkit-extension" ]]; then
  echo "Invalid widget extension point: ${WIDGET_EXTENSION_POINT:-<missing>}." >&2
  exit 1
fi

WIDGET_EXECUTABLE_NAME="$(plutil -extract CFBundleExecutable raw -o - "$WIDGET_INFO_PLIST" 2>/dev/null || true)"
if [[ "$WIDGET_EXECUTABLE_NAME" != "CodexMeterWidget" ]]; then
  echo "Invalid widget CFBundleExecutable: ${WIDGET_EXECUTABLE_NAME:-<missing>}." >&2
  exit 1
fi

ICON_NAME="$(plutil -extract CFBundleIconFile raw -o - "$INFO_PLIST" 2>/dev/null || true)"
if [[ "$ICON_NAME" != "CodexMeter" ]]; then
  echo "Invalid CFBundleIconFile: expected CodexMeter, found ${ICON_NAME:-<missing>}." >&2
  exit 1
fi

readonly APP_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
readonly WIDGET_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$WIDGET_INFO_PLIST")"
if [[ "$APP_VERSION" != "$RELEASE_VERSION" ]]; then
  echo "Release tag $RELEASE_TAG does not match app version $APP_VERSION." >&2
  exit 1
fi

if [[ "$WIDGET_VERSION" != "$APP_VERSION" ]]; then
  echo "Widget version $WIDGET_VERSION does not match app version $APP_VERSION." >&2
  exit 1
fi

codesign --verify --strict "$WIDGET_DIR"
codesign --verify --deep --strict "$APP_DIR"

readonly SIGNED_WIDGET_ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/codexmeter-widget-entitlements.XXXXXX")"
readonly SIGNED_APP_ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/codexmeter-app-entitlements.XXXXXX")"
cleanup_entitlements() {
  rm -f "$SIGNED_WIDGET_ENTITLEMENTS" "$SIGNED_APP_ENTITLEMENTS"
}
trap cleanup_entitlements EXIT
codesign -d --entitlements :- "$WIDGET_DIR" > "$SIGNED_WIDGET_ENTITLEMENTS" 2>/dev/null
codesign -d --entitlements :- "$APP_DIR" > "$SIGNED_APP_ENTITLEMENTS" 2>/dev/null

if plutil -extract 'com\.apple\.security\.app-sandbox' raw -o - "$SIGNED_APP_ENTITLEMENTS" >/dev/null 2>&1 \
  || plutil -extract 'com\.apple\.security\.application-groups' raw -o - "$SIGNED_APP_ENTITLEMENTS" >/dev/null 2>&1; then
  echo "Containing app signature must remain unsandboxed and outside App Groups." >&2
  exit 1
fi

WIDGET_SANDBOX="$(
  plutil -extract 'com\.apple\.security\.app-sandbox' raw -o - "$SIGNED_WIDGET_ENTITLEMENTS" 2>/dev/null || true
)"
WIDGET_READ_PATH="$(
  plutil -extract 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-only.0' raw -o - "$SIGNED_WIDGET_ENTITLEMENTS" 2>/dev/null || true
)"
if [[ "$WIDGET_SANDBOX" != "true" || "$WIDGET_READ_PATH" != "/Library/Application Support/CodexMeter/" ]]; then
  echo "Widget signature is missing the required sandboxed read-only snapshot entitlement." >&2
  exit 1
fi
if plutil -extract 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-only.1' raw -o - "$SIGNED_WIDGET_ENTITLEMENTS" >/dev/null 2>&1 \
  || plutil -extract 'com\.apple\.security\.temporary-exception\.files\.home-relative-path\.read-write' raw -o - "$SIGNED_WIDGET_ENTITLEMENTS" >/dev/null 2>&1 \
  || plutil -extract 'com\.apple\.security\.temporary-exception\.files\.absolute-path\.read-only' raw -o - "$SIGNED_WIDGET_ENTITLEMENTS" >/dev/null 2>&1 \
  || plutil -extract 'com\.apple\.security\.temporary-exception\.files\.absolute-path\.read-write' raw -o - "$SIGNED_WIDGET_ENTITLEMENTS" >/dev/null 2>&1 \
  || plutil -extract 'com\.apple\.security\.application-groups' raw -o - "$SIGNED_WIDGET_ENTITLEMENTS" >/dev/null 2>&1; then
  echo "Widget signature contains unexpected shared-file entitlements." >&2
  exit 1
fi

readonly ARCHS="$(lipo -archs "$EXECUTABLE")"
case " $ARCHS " in
  *" arm64 "*" x86_64 "*|*" x86_64 "*" arm64 "*)
    readonly ASSET_ARCH="universal"
    ;;
  *" arm64 "*)
    readonly ASSET_ARCH="arm64"
    ;;
  *" x86_64 "*)
    readonly ASSET_ARCH="x86_64"
    ;;
  *)
    echo "Unsupported app architectures: $ARCHS" >&2
    exit 1
    ;;
esac

mkdir -p "$OUTPUT_DIR"
readonly ASSET_NAME="CodexMeter-macOS-$ASSET_ARCH.zip"
readonly ASSET_PATH="$OUTPUT_DIR/$ASSET_NAME"
readonly CHECKSUM_PATH="$ASSET_PATH.sha256"

rm -f "$ASSET_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ASSET_PATH"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ASSET_NAME" > "$ASSET_NAME.sha256"
)

echo "Created $ASSET_PATH"
echo "Created $CHECKSUM_PATH"

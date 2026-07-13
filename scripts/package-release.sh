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

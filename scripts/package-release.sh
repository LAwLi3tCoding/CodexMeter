#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'EOF'
Create CodexMeter GitHub Release assets.

Usage:
  ./scripts/package-release.sh v0.4.2

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
  readonly REMOVE_APP_AFTER_PACKAGING=0
else
  "$ROOT_DIR/scripts/build-app.sh" release
  readonly APP_DIR="$ROOT_DIR/build/CodexMeter.app"
  readonly REMOVE_APP_AFTER_PACKAGING=1
fi

readonly INFO_PLIST="$APP_DIR/Contents/Info.plist"
readonly EXECUTABLE="$APP_DIR/Contents/MacOS/CodexMeter"
readonly ICON_PATH="$APP_DIR/Contents/Resources/CodexMeter.icns"
readonly BUNDLED_LICENSE="$APP_DIR/Contents/Resources/LICENSE"
readonly WIDGET_DIR="$APP_DIR/Contents/PlugIns/CodexMeterWidget.appex"
readonly WIDGET_INFO_PLIST="$WIDGET_DIR/Contents/Info.plist"
readonly WIDGET_EXECUTABLE="$WIDGET_DIR/Contents/MacOS/CodexMeterWidget"

assert_release_binary_private() {
  local binary="$1"
  local label="$2"
  local printable_strings
  local local_path_pattern
  local macos_home_prefix linux_home_prefix macos_temp_prefix
  local public_domain_pattern

  macos_home_prefix=$'\x2f\x55\x73\x65\x72\x73\x2f'
  linux_home_prefix=$'\x2f\x68\x6f\x6d\x65\x2f'
  macos_temp_prefix=$'\x2f\x76\x61\x72\x2f\x66\x6f\x6c\x64\x65\x72\x73\x2f'
  local_path_pattern="${macos_home_prefix}|${linux_home_prefix}|${macos_temp_prefix}"
  public_domain_pattern='([a-z0-9-]+\.)+([a-z]{2}|com|net|org|edu|gov|int|mil|info|biz|name|pro|mobi|travel|jobs|museum|aero|asia|cat|tel|dev|app|cloud|tech|xyz|solutions|company|technology|software|systems|digital|online|site|store|agency|tools|services|engineering|consulting|business|work)[[:>:]]'

  if ! printable_strings="$(strings "$binary")"; then
    echo "Privacy check failed for $label: unable to inspect executable strings." >&2
    return 1
  fi

  if print -r -- "$printable_strings" \
    | LC_ALL=C grep -E "$local_path_pattern" >/dev/null; then
    echo "Privacy check failed for $label: local filesystem path detected." >&2
    return 1
  fi

  if print -r -- "$printable_strings" \
    | LC_ALL=C grep -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' >/dev/null; then
    echo "Privacy check failed for $label: email address detected." >&2
    return 1
  fi

  if print -r -- "$printable_strings" \
    | LC_ALL=C grep -Eio "$public_domain_pattern" \
    | tr '[:upper:]' '[:lower:]' \
    | grep -Ev '^com\.(apple|codexmeter)(\.|$)|(^|\.)(apple\.com|openai\.com|github\.com)$' >/dev/null; then
    echo "Privacy check failed for $label: unapproved internet domain detected." >&2
    return 1
  fi
}

if [[ ! -d "$APP_DIR" || ! -f "$INFO_PLIST" || ! -x "$EXECUTABLE" ]]; then
  echo "Invalid CodexMeter app bundle: $APP_DIR" >&2
  exit 1
fi

if [[ ! -f "$ICON_PATH" ]]; then
  echo "Missing app icon: $ICON_PATH" >&2
  exit 1
fi

if [[ ! -f "$BUNDLED_LICENSE" ]]; then
  echo "Missing bundled license: $BUNDLED_LICENSE" >&2
  exit 1
fi

if ! cmp -s "$ROOT_DIR/LICENSE" "$BUNDLED_LICENSE"; then
  echo "Bundled license does not match the project LICENSE." >&2
  exit 1
fi

if [[ ! -d "$WIDGET_DIR" || ! -f "$WIDGET_INFO_PLIST" || ! -x "$WIDGET_EXECUTABLE" ]]; then
  echo "Invalid CodexMeter widget bundle: $WIDGET_DIR" >&2
  exit 1
fi

assert_release_binary_private "$EXECUTABLE" "CodexMeter" || exit 1
assert_release_binary_private "$WIDGET_EXECUTABLE" "CodexMeterWidget" || exit 1

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
ditto -c -k --norsrc --keepParent "$APP_DIR" "$ASSET_PATH"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ASSET_NAME" > "$ASSET_NAME.sha256"
)

if [[ "$REMOVE_APP_AFTER_PACKAGING" == "1" ]]; then
  readonly LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  [[ ! -x "$LSREGISTER" ]] || "$LSREGISTER" -u "$APP_DIR" >/dev/null 2>&1 || true
  rm -rf "$APP_DIR"
fi

echo "Created $ASSET_PATH"
echo "Created $CHECKSUM_PATH"

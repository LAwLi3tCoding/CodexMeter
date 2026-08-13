#!/bin/zsh
set -euo pipefail

readonly REPOSITORY="${CODEXMETER_GITHUB_REPOSITORY:-LAwLi3tCoding/CodexMeter}"
readonly VERSION="${CODEXMETER_VERSION:-latest}"

usage() {
  cat <<'EOF'
Install CodexMeter from GitHub Releases.

Usage:
  curl -fsSL https://raw.githubusercontent.com/LAwLi3tCoding/CodexMeter/main/scripts/install.sh | zsh

Environment variables:
  CODEXMETER_INSTALL_DIR          Destination directory (default: /Applications or ~/Applications)
  CODEXMETER_VERSION              Release tag such as v0.4.3 (default: latest)
  CODEXMETER_GITHUB_REPOSITORY    GitHub owner/repository override
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 0 ]]; then
  usage >&2
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "CodexMeter requires macOS." >&2
  exit 1
fi

case "$(uname -m)" in
  arm64|aarch64)
    readonly ARCH="arm64"
    ;;
  x86_64)
    readonly ARCH="x86_64"
    ;;
  *)
    echo "Unsupported Mac architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

if [[ -n "${CODEXMETER_INSTALL_DIR:-}" ]]; then
  readonly INSTALL_DIR="$CODEXMETER_INSTALL_DIR"
elif [[ -w /Applications ]]; then
  readonly INSTALL_DIR="/Applications"
else
  readonly INSTALL_DIR="$HOME/Applications"
fi

for command_name in curl ditto shasum codesign plutil; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

readonly ASSET_NAME="CodexMeter-macOS-$ARCH.zip"
readonly CHECKSUM_NAME="$ASSET_NAME.sha256"

if [[ "$VERSION" == "latest" ]]; then
  readonly RELEASE_BASE_URL="https://github.com/$REPOSITORY/releases/latest/download"
else
  readonly RELEASE_BASE_URL="https://github.com/$REPOSITORY/releases/download/$VERSION"
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-install.XXXXXX")"
STAGING_APP=""
BACKUP_APP=""

cleanup() {
  local exit_code=$?

  if [[ -n "$BACKUP_APP" && -e "$BACKUP_APP" && ! -e "$INSTALL_DIR/CodexMeter.app" ]]; then
    mv "$BACKUP_APP" "$INSTALL_DIR/CodexMeter.app" || true
  fi

  [[ -n "$STAGING_APP" ]] && rm -rf "$STAGING_APP"
  [[ -n "$BACKUP_APP" ]] && rm -rf "$BACKUP_APP"
  rm -rf "$WORK_DIR"
  return "$exit_code"
}
trap cleanup EXIT

echo "Downloading CodexMeter ${VERSION} for ${ARCH}..."
curl -fsSL -o "$WORK_DIR/$ASSET_NAME" "$RELEASE_BASE_URL/$ASSET_NAME"
curl -fsSL -o "$WORK_DIR/$CHECKSUM_NAME" "$RELEASE_BASE_URL/$CHECKSUM_NAME"

(
  cd "$WORK_DIR"
  shasum -a 256 -c "$CHECKSUM_NAME"
)

mkdir -p "$WORK_DIR/extracted"
ditto -x -k "$WORK_DIR/$ASSET_NAME" "$WORK_DIR/extracted"

readonly DOWNLOADED_APP="$WORK_DIR/extracted/CodexMeter.app"
if [[ ! -d "$DOWNLOADED_APP" ]]; then
  echo "Release archive does not contain CodexMeter.app." >&2
  exit 1
fi

readonly INFO_PLIST="$DOWNLOADED_APP/Contents/Info.plist"
readonly WIDGET_DIR="$DOWNLOADED_APP/Contents/PlugIns/CodexMeterWidget.appex"
readonly WIDGET_INFO_PLIST="$WIDGET_DIR/Contents/Info.plist"
readonly WIDGET_EXECUTABLE="$WIDGET_DIR/Contents/MacOS/CodexMeterWidget"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Release app does not contain Info.plist." >&2
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

readonly APP_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
readonly WIDGET_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$WIDGET_INFO_PLIST")"
if [[ "$WIDGET_VERSION" != "$APP_VERSION" ]]; then
  echo "Widget version $WIDGET_VERSION does not match app version $APP_VERSION." >&2
  exit 1
fi

codesign --verify --strict "$WIDGET_DIR"
codesign --verify --deep --strict "$DOWNLOADED_APP"

readonly SIGNED_WIDGET_ENTITLEMENTS="$WORK_DIR/widget-entitlements.plist"
readonly SIGNED_APP_ENTITLEMENTS="$WORK_DIR/app-entitlements.plist"
codesign -d --entitlements :- "$WIDGET_DIR" > "$SIGNED_WIDGET_ENTITLEMENTS" 2>/dev/null
codesign -d --entitlements :- "$DOWNLOADED_APP" > "$SIGNED_APP_ENTITLEMENTS" 2>/dev/null
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

mkdir -p "$INSTALL_DIR"
STAGING_APP="$INSTALL_DIR/.CodexMeter.app.installing.$$"
BACKUP_APP="$INSTALL_DIR/.CodexMeter.app.backup.$$"
ditto "$DOWNLOADED_APP" "$STAGING_APP"

if [[ -e "$INSTALL_DIR/CodexMeter.app" ]]; then
  mv "$INSTALL_DIR/CodexMeter.app" "$BACKUP_APP"
fi

if ! mv "$STAGING_APP" "$INSTALL_DIR/CodexMeter.app"; then
  echo "Unable to install CodexMeter into $INSTALL_DIR." >&2
  exit 1
fi
STAGING_APP=""

rm -rf "$BACKUP_APP"
BACKUP_APP=""

echo "Installed CodexMeter at $INSTALL_DIR/CodexMeter.app"
echo "Launch it with: open '$INSTALL_DIR/CodexMeter.app'"

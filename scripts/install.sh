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
  CODEXMETER_VERSION              Release tag such as v0.1.0 (default: latest)
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

for command_name in curl ditto shasum codesign; do
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

codesign --verify --deep --strict "$DOWNLOADED_APP"

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

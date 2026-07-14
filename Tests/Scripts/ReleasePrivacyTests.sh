#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT_DIR/build/CodexMeter.app"
APP_EXECUTABLE="$APP_DIR/Contents/MacOS/CodexMeter"
WIDGET_EXECUTABLE="$APP_DIR/Contents/PlugIns/CodexMeterWidget.appex/Contents/MacOS/CodexMeterWidget"
BUNDLED_LICENSE="$APP_DIR/Contents/Resources/LICENSE"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-release-privacy-tests.XXXXXX")"
OUTPUT_DIR="$TEST_ROOT/dist"
EXTRACT_DIR="$TEST_ROOT/extracted"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_binary_is_private() {
  local binary="$1"
  local label="$2"
  local strings_file="$TEST_ROOT/${label}.strings"
  local public_domain_pattern

  public_domain_pattern='([a-z0-9-]+\.)+([a-z]{2}|com|net|org|edu|gov|int|mil|info|biz|name|pro|mobi|travel|jobs|museum|aero|asia|cat|tel|dev|app|cloud|tech|xyz|solutions|company|technology|software|systems|digital|online|site|store|agency|tools|services|engineering|consulting|business|work)[[:>:]]'

  strings -a - < "$binary" > "$strings_file"

  if LC_ALL=C grep -Eq '/Users/|/home/|/var/folders/' "$strings_file"; then
    fail "$label contains a local filesystem path"
  fi

  if LC_ALL=C grep -Eq '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$strings_file"; then
    fail "$label contains an email address"
  fi

  if LC_ALL=C grep -Eio "$public_domain_pattern" "$strings_file" \
    | tr '[:upper:]' '[:lower:]' \
    | grep -Ev '^com\.(apple|codexmeter)(\.|$)|(^|\.)(apple\.com|openai\.com|github\.com)$' >/dev/null; then
    fail "$label contains an unapproved internet domain"
  fi
}

CODEXMETER_OUTPUT_DIR="$OUTPUT_DIR" \
  "$ROOT_DIR/scripts/package-release.sh" v0.1.0 >/dev/null

release_assets=("$OUTPUT_DIR"/CodexMeter-macOS-*.zip(N))
(( ${#release_assets} == 1 )) || fail "expected exactly one architecture-specific release archive"
ASSET_PATH="${release_assets[1]}"

[[ -x "$APP_EXECUTABLE" ]] || fail "missing app executable"
[[ -x "$WIDGET_EXECUTABLE" ]] || fail "missing widget executable"
[[ -f "$BUNDLED_LICENSE" ]] || fail "app bundle is missing LICENSE"
cmp -s "$ROOT_DIR/LICENSE" "$BUNDLED_LICENSE" \
  || fail "app bundle LICENSE differs from the project LICENSE"

assert_binary_is_private "$APP_EXECUTABLE" "CodexMeter"
assert_binary_is_private "$WIDGET_EXECUTABLE" "CodexMeterWidget"

[[ -f "$ASSET_PATH" ]] || fail "release archive was not created"
[[ -f "$ASSET_PATH.sha256" ]] || fail "release checksum was not created"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 -c "${ASSET_PATH:t}.sha256" >/dev/null
) || fail "release checksum is invalid"

unzip -p "$ASSET_PATH" "CodexMeter.app/Contents/Resources/LICENSE" \
  | cmp -s "$ROOT_DIR/LICENSE" - \
  || fail "release archive does not contain the canonical MIT license"

if unzip -Z1 "$ASSET_PATH" | grep '^__MACOSX/' >/dev/null; then
  fail "release archive contains AppleDouble metadata"
fi

mkdir -p "$EXTRACT_DIR"
ditto -x -k "$ASSET_PATH" "$EXTRACT_DIR"
ARCHIVED_APP="$EXTRACT_DIR/CodexMeter.app"
ARCHIVED_WIDGET="$ARCHIVED_APP/Contents/PlugIns/CodexMeterWidget.appex"

[[ -d "$ARCHIVED_APP" ]] || fail "release archive does not contain CodexMeter.app"
cmp -s "$ROOT_DIR/LICENSE" "$ARCHIVED_APP/Contents/Resources/LICENSE" \
  || fail "extracted app LICENSE differs from the project LICENSE"
assert_binary_is_private "$ARCHIVED_APP/Contents/MacOS/CodexMeter" "ArchivedCodexMeter"
assert_binary_is_private "$ARCHIVED_WIDGET/Contents/MacOS/CodexMeterWidget" "ArchivedCodexMeterWidget"
codesign --verify --strict --verbose=2 "$ARCHIVED_WIDGET"
codesign --verify --deep --strict --verbose=2 "$ARCHIVED_APP"

echo "PASS: release privacy and license integrity"

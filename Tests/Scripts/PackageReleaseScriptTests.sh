#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PACKAGE_SCRIPT="$ROOT_DIR/scripts/package-release.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-package-tests.XXXXXX")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

make_fake_app() {
  local app_dir="$1"
  local version="$2"

  mkdir -p "$app_dir/Contents/MacOS"
  print -r -- "binary" > "$app_dir/Contents/MacOS/CodexMeter"
  chmod +x "$app_dir/Contents/MacOS/CodexMeter"
  cat > "$app_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
</dict>
</plist>
EOF
}

make_fake_commands() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/codesign" <<'EOF'
#!/bin/zsh
exit 0
EOF

  cat > "$bin_dir/lipo" <<'EOF'
#!/bin/zsh
echo "${FAKE_LIPO_ARCHS:-arm64}"
EOF

  chmod +x "$bin_dir/codesign" "$bin_dir/lipo"
}

test_help() {
  local output
  output="$(zsh "$PACKAGE_SCRIPT" --help)"
  [[ "$output" == *"Create CodexMeter GitHub Release assets"* ]] || fail "help text is missing"
}

test_packages_matching_app_version() {
  local case_dir="$TEST_ROOT/success"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local asset="$output_dir/CodexMeter-macOS-arm64.zip"

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"

  CODEXMETER_APP_PATH="$app_dir" \
  CODEXMETER_OUTPUT_DIR="$output_dir" \
  PATH="$bin_dir:$PATH" \
  zsh "$PACKAGE_SCRIPT" v0.1.0 >/dev/null

  [[ -f "$asset" ]] || fail "release archive was not created"
  [[ -f "$asset.sha256" ]] || fail "checksum file was not created"
  (
    cd "$output_dir"
    shasum -a 256 -c "${asset:t}.sha256" >/dev/null
  ) || fail "release checksum is invalid"
}

test_rejects_version_mismatch() {
  local case_dir="$TEST_ROOT/version-mismatch"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"

  if CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.2.0 >/dev/null 2>&1; then
    fail "packager accepted a tag that does not match the app version"
  fi
}

test_help
test_packages_matching_app_version
test_rejects_version_mismatch

echo "PASS: release packaging script"

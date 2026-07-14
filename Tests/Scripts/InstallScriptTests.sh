#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/scripts/install.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-install-tests.XXXXXX")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

make_fake_release() {
  local release_dir="$1"
  local payload="$2"
  local widget_state="${3:-valid}"
  local asset_name="CodexMeter-macOS-arm64.zip"
  local app_dir="$release_dir/payload/CodexMeter.app"
  local widget_dir="$app_dir/Contents/PlugIns/CodexMeterWidget.appex"

  mkdir -p "$app_dir/Contents/MacOS" "$widget_dir/Contents/MacOS"
  print -r -- "$payload" > "$app_dir/Contents/MacOS/CodexMeter"
  chmod +x "$app_dir/Contents/MacOS/CodexMeter"
  print -r -- "widget binary" > "$widget_dir/Contents/MacOS/CodexMeterWidget"
  chmod +x "$widget_dir/Contents/MacOS/CodexMeterWidget"
  cat > "$app_dir/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
</dict>
</plist>
EOF
  cat > "$widget_dir/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CodexMeterWidget</string>
  <key>CFBundleIdentifier</key>
  <string>com.codexmeter.CodexMeter.Widget</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
EOF

  case "$widget_state" in
    valid)
      ;;
    missing)
      rm -rf "$widget_dir"
      ;;
    invalid-point)
      plutil -replace NSExtension.NSExtensionPointIdentifier -string com.apple.invalid-extension \
        "$widget_dir/Contents/Info.plist"
      ;;
    *)
      fail "unknown widget fixture state: $widget_state"
      ;;
  esac

  ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$release_dir/$asset_name"
  (
    cd "$release_dir"
    shasum -a 256 "$asset_name" > "$asset_name.sha256"
  )
}

make_fake_commands() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/curl" <<'EOF'
#!/bin/zsh
set -euo pipefail

output=""
url=""
while (( $# > 0 )); do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -* )
      shift
      ;;
    * )
      url="$1"
      shift
      ;;
  esac
done

cp "$FAKE_RELEASE_DIR/${url:t}" "$output"
EOF

  cat > "$bin_dir/codesign" <<'EOF'
#!/bin/zsh
set -euo pipefail

if [[ "$*" == *"--entitlements :-"* ]]; then
  target="${@: -1}"
  if [[ "$target" != *"CodexMeterWidget.appex" ]]; then
    if [[ "${FAKE_WIDGET_ENTITLEMENT_STATE:-valid}" == "sandboxed-app" ]]; then
      print -r -- '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>'
    else
      print -r -- '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>'
    fi
  elif [[ "${FAKE_WIDGET_ENTITLEMENT_STATE:-valid}" == "missing-read" ]]; then
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
</dict></plist>
PLIST
  elif [[ "${FAKE_WIDGET_ENTITLEMENT_STATE:-valid}" == "wrong-read" ]]; then
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
  <array><string>/Library/Application Support/OtherApp/</string></array>
</dict></plist>
PLIST
  elif [[ "${FAKE_WIDGET_ENTITLEMENT_STATE:-valid}" == "extra-read" ]]; then
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
  <array>
    <string>/Library/Application Support/CodexMeter/</string>
    <string>/Documents/</string>
  </array>
</dict></plist>
PLIST
  elif [[ "${FAKE_WIDGET_ENTITLEMENT_STATE:-valid}" == "read-write" ]]; then
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
  <array><string>/Library/Application Support/CodexMeter/</string></array>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
  <array><string>/Documents/</string></array>
</dict></plist>
PLIST
  elif [[ "${FAKE_WIDGET_ENTITLEMENT_STATE:-valid}" == "absolute-path" ]]; then
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
  <array><string>/Library/Application Support/CodexMeter/</string></array>
  <key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
  <array><string>/private/tmp/</string></array>
</dict></plist>
PLIST
  elif [[ "${FAKE_WIDGET_ENTITLEMENT_STATE:-valid}" == "app-group" ]]; then
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
  <array><string>/Library/Application Support/CodexMeter/</string></array>
  <key>com.apple.security.application-groups</key>
  <array><string>group.com.codexmeter.Unexpected</string></array>
</dict></plist>
PLIST
  else
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
  <array><string>/Library/Application Support/CodexMeter/</string></array>
</dict></plist>
PLIST
  fi
fi
exit 0
EOF

  chmod +x "$bin_dir/curl" "$bin_dir/codesign"
}

test_help() {
  local output
  output="$(zsh "$INSTALL_SCRIPT" --help)"
  assert_contains "$output" "Install CodexMeter from GitHub Releases"
}

test_installs_verified_release() {
  local case_dir="$TEST_ROOT/success"
  local release_dir="$case_dir/release"
  local install_dir="$case_dir/Applications"
  local bin_dir="$case_dir/bin"
  local output

  mkdir -p "$release_dir" "$install_dir"
  make_fake_release "$release_dir" "new-release"
  make_fake_commands "$bin_dir"

  output="$(
    FAKE_RELEASE_DIR="$release_dir" \
    CODEXMETER_INSTALL_DIR="$install_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$INSTALL_SCRIPT" 2>"$case_dir/stderr"
  )"

  [[ ! -s "$case_dir/stderr" ]] || fail "successful install wrote to stderr: $(<"$case_dir/stderr")"
  [[ -x "$install_dir/CodexMeter.app/Contents/MacOS/CodexMeter" ]] || fail "app was not installed"
  [[ "$(<"$install_dir/CodexMeter.app/Contents/MacOS/CodexMeter")" == "new-release" ]] || fail "installed payload does not match release"
  assert_contains "$output" "Installed CodexMeter"
}

test_rejects_bad_checksum_without_replacing_existing_app() {
  local case_dir="$TEST_ROOT/bad-checksum"
  local release_dir="$case_dir/release"
  local install_dir="$case_dir/Applications"
  local bin_dir="$case_dir/bin"
  local existing_binary="$install_dir/CodexMeter.app/Contents/MacOS/CodexMeter"

  mkdir -p "$release_dir" "${existing_binary:h}"
  print -r -- "existing-release" > "$existing_binary"
  make_fake_release "$release_dir" "untrusted-release"
  make_fake_commands "$bin_dir"
  print -r -- "0000000000000000000000000000000000000000000000000000000000000000  CodexMeter-macOS-arm64.zip" \
    > "$release_dir/CodexMeter-macOS-arm64.zip.sha256"

  if FAKE_RELEASE_DIR="$release_dir" \
    CODEXMETER_INSTALL_DIR="$install_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$INSTALL_SCRIPT" >/dev/null 2>&1; then
    fail "installer accepted a release with an invalid checksum"
  fi

  [[ "$(<"$existing_binary")" == "existing-release" ]] || fail "existing app changed after checksum failure"
}

test_rejects_missing_widget_without_replacing_existing_app() {
  local case_dir="$TEST_ROOT/missing-widget"
  local release_dir="$case_dir/release"
  local install_dir="$case_dir/Applications"
  local bin_dir="$case_dir/bin"
  local existing_binary="$install_dir/CodexMeter.app/Contents/MacOS/CodexMeter"

  mkdir -p "$release_dir" "${existing_binary:h}"
  print -r -- "existing-release" > "$existing_binary"
  make_fake_release "$release_dir" "incomplete-release" missing
  make_fake_commands "$bin_dir"

  if FAKE_RELEASE_DIR="$release_dir" \
    CODEXMETER_INSTALL_DIR="$install_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$INSTALL_SCRIPT" >/dev/null 2>&1; then
    fail "installer accepted a release without CodexMeterWidget.appex"
  fi

  [[ "$(<"$existing_binary")" == "existing-release" ]] || fail "existing app changed after widget validation failure"
}

test_rejects_invalid_widget_extension_point_without_replacing_existing_app() {
  local case_dir="$TEST_ROOT/invalid-widget-point"
  local release_dir="$case_dir/release"
  local install_dir="$case_dir/Applications"
  local bin_dir="$case_dir/bin"
  local existing_binary="$install_dir/CodexMeter.app/Contents/MacOS/CodexMeter"

  mkdir -p "$release_dir" "${existing_binary:h}"
  print -r -- "existing-release" > "$existing_binary"
  make_fake_release "$release_dir" "invalid-release" invalid-point
  make_fake_commands "$bin_dir"

  if FAKE_RELEASE_DIR="$release_dir" \
    CODEXMETER_INSTALL_DIR="$install_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$INSTALL_SCRIPT" >/dev/null 2>&1; then
    fail "installer accepted an invalid widget extension point"
  fi

  [[ "$(<"$existing_binary")" == "existing-release" ]] || fail "existing app changed after widget validation failure"
}

test_rejects_invalid_signed_entitlements_without_replacing_existing_app() {
  local entitlement_state
  for entitlement_state in missing-read wrong-read extra-read read-write absolute-path app-group sandboxed-app; do
    local case_dir="$TEST_ROOT/invalid-entitlement-$entitlement_state"
    local release_dir="$case_dir/release"
    local install_dir="$case_dir/Applications"
    local bin_dir="$case_dir/bin"
    local existing_binary="$install_dir/CodexMeter.app/Contents/MacOS/CodexMeter"

    mkdir -p "$release_dir" "${existing_binary:h}"
    print -r -- "existing-release" > "$existing_binary"
    make_fake_release "$release_dir" "unsafe-widget-release"
    make_fake_commands "$bin_dir"

    if FAKE_RELEASE_DIR="$release_dir" \
      FAKE_WIDGET_ENTITLEMENT_STATE="$entitlement_state" \
      CODEXMETER_INSTALL_DIR="$install_dir" \
      PATH="$bin_dir:$PATH" \
      zsh "$INSTALL_SCRIPT" >/dev/null 2>&1; then
      fail "installer accepted invalid signed entitlements: $entitlement_state"
    fi

    [[ "$(<"$existing_binary")" == "existing-release" ]] || fail "existing app changed after entitlement validation failure: $entitlement_state"
  done
}

test_help
test_installs_verified_release
test_rejects_bad_checksum_without_replacing_existing_app
test_rejects_missing_widget_without_replacing_existing_app
test_rejects_invalid_widget_extension_point_without_replacing_existing_app
test_rejects_invalid_signed_entitlements_without_replacing_existing_app

echo "PASS: install script"

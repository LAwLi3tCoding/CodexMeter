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
  local widget_dir="$app_dir/Contents/PlugIns/CodexMeterWidget.appex"

  mkdir -p \
    "$app_dir/Contents/MacOS" \
    "$app_dir/Contents/Resources" \
    "$widget_dir/Contents/MacOS"
  print -r -- "binary" > "$app_dir/Contents/MacOS/CodexMeter"
  chmod +x "$app_dir/Contents/MacOS/CodexMeter"
  print -r -- "widget binary" > "$widget_dir/Contents/MacOS/CodexMeterWidget"
  chmod +x "$widget_dir/Contents/MacOS/CodexMeterWidget"
  print -r -- "placeholder icon" > "$app_dir/Contents/Resources/CodexMeter.icns"
  cp "$ROOT_DIR/LICENSE" "$app_dir/Contents/Resources/LICENSE"
  cat > "$app_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>CFBundleIconFile</key>
  <string>CodexMeter</string>
</dict>
</plist>
EOF
  cat > "$widget_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CodexMeterWidget</string>
  <key>CFBundleIdentifier</key>
  <string>com.codexmeter.CodexMeter.Widget</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
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
}

make_fake_commands() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"

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
  unzip -p "$asset" "CodexMeter.app/Contents/Resources/LICENSE" \
    | cmp -s "$ROOT_DIR/LICENSE" - \
    || fail "release archive does not contain the canonical MIT license"
  if unzip -Z1 "$asset" | grep '^__MACOSX/' >/dev/null; then
    fail "release archive contains AppleDouble metadata"
  fi
}

test_rejects_missing_license() {
  local case_dir="$TEST_ROOT/missing-license"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local output

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  rm "$app_dir/Contents/Resources/LICENSE"

  if output="$(
    CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 2>&1
  )"; then
    fail "packager accepted an app without the project license"
  fi
  [[ "$output" == *"Missing bundled license: $app_dir/Contents/Resources/LICENSE"* ]] \
    || fail "missing license error is unclear: $output"
}

test_rejects_mismatched_license() {
  local case_dir="$TEST_ROOT/mismatched-license"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local output

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  print -r -- "not the project license" > "$app_dir/Contents/Resources/LICENSE"

  if output="$(
    CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 2>&1
  )"; then
    fail "packager accepted a modified project license"
  fi
  [[ "$output" == *"Bundled license does not match the project LICENSE."* ]] \
    || fail "mismatched license error is unclear: $output"
}

test_rejects_local_path_in_existing_app() {
  local case_dir="$TEST_ROOT/private-path"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local output

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  print -r -- "/Users/example/private/source.swift" >> "$app_dir/Contents/MacOS/CodexMeter"

  if output="$(
    CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 2>&1
  )"; then
    fail "packager accepted an existing app with a local filesystem path"
  fi
  [[ "$output" == *"Privacy check failed for CodexMeter: local filesystem path detected."* ]] \
    || fail "local path error is unclear: $output"
}

test_rejects_email_in_existing_widget() {
  local case_dir="$TEST_ROOT/private-email"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local output

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  print -r -- "developer@example.com" \
    >> "$app_dir/Contents/PlugIns/CodexMeterWidget.appex/Contents/MacOS/CodexMeterWidget"

  if output="$(
    CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 2>&1
  )"; then
    fail "packager accepted an existing widget with an email address"
  fi
  [[ "$output" == *"Privacy check failed for CodexMeterWidget: email address detected."* ]] \
    || fail "email error is unclear: $output"
}

test_rejects_unapproved_domain_in_existing_app() {
  local leaked_domains=(
    "SERVICE.PRIVATE-EXAMPLE.COM"
    "corp.private-example.xyz"
    "service.private-example.solutions"
  )
  local index=0
  local leaked_domain case_dir app_dir output_dir bin_dir
  local output

  for leaked_domain in "${leaked_domains[@]}"; do
    index=$((index + 1))
    case_dir="$TEST_ROOT/private-domain-$index"
    app_dir="$case_dir/CodexMeter.app"
    output_dir="$case_dir/dist"
    bin_dir="$case_dir/bin"

    make_fake_app "$app_dir" "0.1.0"
    make_fake_commands "$bin_dir"
    print -r -- "$leaked_domain" >> "$app_dir/Contents/MacOS/CodexMeter"

    if output="$(
      CODEXMETER_APP_PATH="$app_dir" \
      CODEXMETER_OUTPUT_DIR="$output_dir" \
      PATH="$bin_dir:$PATH" \
      zsh "$PACKAGE_SCRIPT" v0.1.0 2>&1
    )"; then
      fail "packager accepted an existing app with an unapproved internet domain"
    fi
    [[ "$output" == *"Privacy check failed for CodexMeter: unapproved internet domain detected."* ]] \
      || fail "domain error is unclear: $output"
  done
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

test_rejects_missing_icon() {
  local case_dir="$TEST_ROOT/missing-icon"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local output

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  rm "$app_dir/Contents/Resources/CodexMeter.icns"

  if output="$(
    CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 2>&1
  )"; then
    fail "packager accepted an app without CodexMeter.icns"
  fi
  [[ "$output" == *"Missing app icon: $app_dir/Contents/Resources/CodexMeter.icns"* ]] \
    || fail "missing icon error is unclear: $output"
}

test_rejects_icon_metadata_mismatch() {
  local case_dir="$TEST_ROOT/icon-metadata-mismatch"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local output

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  plutil -replace CFBundleIconFile -string OtherIcon "$app_dir/Contents/Info.plist"

  if output="$(
    CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 2>&1
  )"; then
    fail "packager accepted mismatched icon metadata"
  fi
  [[ "$output" == *"Invalid CFBundleIconFile: expected CodexMeter, found OtherIcon."* ]] \
    || fail "icon metadata error is unclear: $output"
}

test_rejects_missing_widget_extension() {
  local case_dir="$TEST_ROOT/missing-widget"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  rm -rf "$app_dir/Contents/PlugIns/CodexMeterWidget.appex"

  if CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 >/dev/null 2>&1; then
    fail "packager accepted an app without CodexMeterWidget.appex"
  fi
}

test_rejects_invalid_widget_extension_point() {
  local case_dir="$TEST_ROOT/invalid-widget-point"
  local app_dir="$case_dir/CodexMeter.app"
  local output_dir="$case_dir/dist"
  local bin_dir="$case_dir/bin"
  local widget_info="$app_dir/Contents/PlugIns/CodexMeterWidget.appex/Contents/Info.plist"

  make_fake_app "$app_dir" "0.1.0"
  make_fake_commands "$bin_dir"
  plutil -replace NSExtension.NSExtensionPointIdentifier -string com.apple.invalid-extension "$widget_info"

  if CODEXMETER_APP_PATH="$app_dir" \
    CODEXMETER_OUTPUT_DIR="$output_dir" \
    PATH="$bin_dir:$PATH" \
    zsh "$PACKAGE_SCRIPT" v0.1.0 >/dev/null 2>&1; then
    fail "packager accepted an invalid widget extension point"
  fi
}

test_rejects_invalid_signed_entitlements() {
  local entitlement_state
  for entitlement_state in missing-read wrong-read extra-read read-write absolute-path app-group sandboxed-app; do
    local case_dir="$TEST_ROOT/invalid-entitlement-$entitlement_state"
    local app_dir="$case_dir/CodexMeter.app"
    local output_dir="$case_dir/dist"
    local bin_dir="$case_dir/bin"

    make_fake_app "$app_dir" "0.1.0"
    make_fake_commands "$bin_dir"

    if FAKE_WIDGET_ENTITLEMENT_STATE="$entitlement_state" \
      CODEXMETER_APP_PATH="$app_dir" \
      CODEXMETER_OUTPUT_DIR="$output_dir" \
      PATH="$bin_dir:$PATH" \
      zsh "$PACKAGE_SCRIPT" v0.1.0 >/dev/null 2>&1; then
      fail "packager accepted invalid signed entitlements: $entitlement_state"
    fi
  done
}

test_help
test_packages_matching_app_version
test_rejects_missing_license
test_rejects_mismatched_license
test_rejects_local_path_in_existing_app
test_rejects_email_in_existing_widget
test_rejects_unapproved_domain_in_existing_app
test_rejects_version_mismatch
test_rejects_missing_icon
test_rejects_icon_metadata_mismatch
test_rejects_missing_widget_extension
test_rejects_invalid_widget_extension_point
test_rejects_invalid_signed_entitlements

echo "PASS: release packaging script"

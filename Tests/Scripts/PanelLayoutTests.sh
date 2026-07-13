#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PANEL_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/StatusPanelView.swift"

fail() {
  echo "FAIL [panel-layout] $1" >&2
  exit 1
}

if grep -Eq 'ScrollView|List\s*\{|DisclosureGroup|\.frame\(maxHeight:' "$PANEL_FILE"; then
  fail "status panel must expose every quota without scrolling, disclosure, or a height cap"
fi

grep -Fq 'GridItem(.flexible(), spacing: 10)' "$PANEL_FILE" \
  || fail "status panel must use the two-column quota grid"
grep -Fq '.frame(width: 448)' "$PANEL_FILE" \
  || fail "status panel must use the readable 448-point width"
grep -Fq '.fixedSize(horizontal: false, vertical: true)' "$PANEL_FILE" \
  || fail "status panel must grow vertically to expose every quota"
grep -Fq 'ForEach(presentation.quotaCards, id: \.id)' "$PANEL_FILE" \
  || fail "status panel must render every prepared quota card"

echo "PASS [panel-layout] all quota windows remain visible without an internal scroll view"

#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PANEL_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/StatusPanelView.swift"
MENU_BAR_FILE="$ROOT_DIR/Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift"
QUOTA_CARD_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/QuotaCardView.swift"

fail() {
  echo "FAIL [panel-layout] $1" >&2
  exit 1
}

if grep -Eq 'ScrollView|List[[:space:]]*[({]|DisclosureGroup|maxHeight[[:space:]]*:' "$PANEL_FILE"; then
  fail "status panel must expose every quota without scrolling, disclosure, or a height cap"
fi

grep -Fq 'GridItem(.flexible(), spacing: 10)' "$PANEL_FILE" \
  || fail "status panel must use the two-column quota grid"
grep -Fq '.frame(width: 464)' "$PANEL_FILE" \
  || fail "status panel must use the refined 464-point width"
grep -Fq '.fixedSize(horizontal: false, vertical: true)' "$PANEL_FILE" \
  || fail "status panel must grow vertically to expose every quota"
grep -Fq 'ForEach(presentation.quotaCards, id: \.id)' "$PANEL_FILE" \
  || fail "status panel must render every prepared quota card"
grep -Fq 'Text(presentation.brandText)' "$MENU_BAR_FILE" \
  || fail "menu bar must identify Codex"
grep -Fq '.monospacedDigit()' "$MENU_BAR_FILE" \
  || fail "menu bar values must not jitter"
grep -Fq 'SegmentedQuotaGauge(' "$QUOTA_CARD_FILE" \
  || fail "quota cards must use the segmented gauge"
if grep -Fq 'ProgressView(value: presentation.progress)' "$QUOTA_CARD_FILE"; then
  fail "quota cards must not use the generic linear progress view"
fi

echo "PASS [panel-layout] all quota windows remain visible without an internal scroll view"

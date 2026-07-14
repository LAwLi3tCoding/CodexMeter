#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PANEL_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/StatusPanelView.swift"
MENU_BAR_FILE="$ROOT_DIR/Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift"
QUOTA_CARD_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/QuotaCardView.swift"
PANEL_HEADER_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/PanelHeaderView.swift"
PANEL_FOOTER_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/PanelFooterView.swift"

fail() {
  echo "FAIL [panel-layout] $1" >&2
  exit 1
}

if grep -Eq 'List[[:space:]]*[({]|DisclosureGroup' "$PANEL_FILE"; then
  fail "status panel must not hide quotas in a list or disclosure control"
fi

grep -Fq 'if presentation.requiresQuotaOverflow {' "$PANEL_FILE" \
  || fail "status panel must gate its overflow fallback on presentation state"
grep -Fq 'ScrollView {' "$PANEL_FILE" \
  || fail "status panel must provide overflow access for large quota collections"
grep -Fq '.frame(maxHeight: 410)' "$PANEL_FILE" \
  || fail "quota overflow must be capped at 410 points"
grep -Fq 'GridItem(.flexible(), spacing: 10)' "$PANEL_FILE" \
  || fail "status panel must use the two-column quota grid"
grep -Fq '.frame(width: 464)' "$PANEL_FILE" \
  || fail "status panel must use the refined 464-point width"
grep -Fq '.fixedSize(horizontal: false, vertical: true)' "$PANEL_FILE" \
  || fail "status panel must grow vertically to expose every quota"
grep -Fq 'ForEach(presentation.quotaCards, id: \.id)' "$PANEL_FILE" \
  || fail "status panel must render every prepared quota card"
grep -Fq 'Text(presentation.displayText)' "$MENU_BAR_FILE" \
  || fail "menu bar must keep Codex and its quota in one status text"
grep -Fq '.monospacedDigit()' "$MENU_BAR_FILE" \
  || fail "menu bar values must not jitter"
grep -Fq 'fillAmounts: presentation.segmentFillAmounts' "$QUOTA_CARD_FILE" \
  || fail "quota cards must consume presentation-owned segment fill amounts"
if grep -Fq 'ProgressView(value: presentation.progress)' "$QUOTA_CARD_FILE"; then
  fail "quota cards must not use the generic linear progress view"
fi
grep -Fq '.easeOut(duration: 0.22)' "$QUOTA_CARD_FILE" \
  || fail "quota gauge changes must use an ease-out transition"
if grep -Eq '\.font\(\.system\(size: 9|\.foregroundStyle\(\.tertiary\)' "$PANEL_HEADER_FILE"; then
  fail "metadata labels must use semantic caption typography and secondary color"
fi
[[ "$(grep -Fc '.font(.caption2.weight(.semibold))' "$PANEL_HEADER_FILE")" -ge 2 ]] \
  || fail "metadata labels must use caption2 semibold typography"
grep -Fq 'Text("后台自动更新")' "$PANEL_FOOTER_FILE" \
  || fail "auto-refresh detail must not promise a fixed cadence"

echo "PASS [panel-layout] common quotas use the grid and large collections have bounded overflow"

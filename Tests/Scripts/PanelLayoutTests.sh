#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PANEL_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/StatusPanelView.swift"
MENU_BAR_FILE="$ROOT_DIR/Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift"
QUOTA_CARD_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/QuotaCardView.swift"
PANEL_HEADER_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/PanelHeaderView.swift"
PANEL_FOOTER_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/PanelFooterView.swift"
USAGE_DASHBOARD_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/UsageDashboardView.swift"
QUOTA_FORMATTER_FILE="$ROOT_DIR/Sources/CodexMeterCore/Support/QuotaFormatter.swift"
QUOTA_PRESENTATION_FILE="$ROOT_DIR/Sources/CodexMeterCore/Models/QuotaCardPresentation.swift"
QUOTA_STORE_FILE="$ROOT_DIR/Sources/CodexMeterCore/State/QuotaStore.swift"

fail() {
  echo "FAIL [panel-layout] $1" >&2
  exit 1
}

if grep -Eq 'List[[:space:]]*[({]|DisclosureGroup' "$PANEL_FILE"; then
  fail "status panel must not hide quotas in a list or disclosure control"
fi

grep -Fq 'ScrollView {' "$PANEL_FILE" \
  || fail "status panel must keep the dashboard body scrollable"
grep -Fq '.frame(maxHeight: 520)' "$PANEL_FILE" \
  || fail "dashboard content must have a compact bounded scroll region"
grep -Fq 'GridItem(.flexible(), spacing: 8)' "$PANEL_FILE" \
  || fail "status panel must use the two-column quota grid"
grep -Fq '.frame(width: 460)' "$PANEL_FILE" \
  || fail "usage dashboard must use the compact 460-point width"
grep -Fq '.fixedSize(horizontal: false, vertical: true)' "$PANEL_FILE" \
  || fail "status panel must grow vertically to expose every quota"
grep -Fq 'ForEach(presentation.quotaCards, id: \.id)' "$PANEL_FILE" \
  || fail "status panel must render every prepared quota card"
grep -Fq 'UsageDashboardView(' "$PANEL_FILE" \
  || fail "status panel must render the usage dashboard"
grep -Fq 'isStale: store.usageFailure != nil' "$PANEL_FILE" \
  || fail "retained usage data must visibly identify a failed refresh"
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
grep -Fq 'presentation.displayStyle == .compact' "$QUOTA_CARD_FILE" \
  || fail "weekly quota must receive compact visual emphasis"
if grep -Eq '\.font\(\.system\(size: 9|\.foregroundStyle\(\.tertiary\)' "$PANEL_HEADER_FILE"; then
  fail "metadata labels must use semantic caption typography and secondary color"
fi
[[ "$(grep -Fc '.font(.caption2.weight(.semibold))' "$PANEL_HEADER_FILE")" -ge 2 ]] \
  || fail "metadata labels must use caption2 semibold typography"
grep -Fq 'Text("Background updates")' "$PANEL_FOOTER_FILE" \
  || fail "auto-refresh detail must not promise a fixed cadence"
grep -Fq 'LocalProxySettingsView(store: store)' "$PANEL_FOOTER_FILE" \
  || fail "the panel must expose local proxy configuration"
grep -Fq '.frame(height: 82)' "$USAGE_DASHBOARD_FILE" \
  || fail "the thirty-day chart must keep its compact height"
grep -Fq '.font(.system(size: 13, weight: .semibold, design: .rounded))' "$USAGE_DASHBOARD_FILE" \
  || fail "usage summary values must keep compact typography"
grep -Fq 'Color(nsColor: .systemBlue)' "$USAGE_DASHBOARD_FILE" \
  || fail "the usage dashboard must use one coherent cool data accent"
grep -Fq '.onContinuousHover(coordinateSpace: .local)' "$USAGE_DASHBOARD_FILE" \
  || fail "the daily token bars must expose mouse hover details"
grep -Fq '.fill(Color.primary.opacity(0.001))' "$USAGE_DASHBOARD_FILE" \
  || fail "the chart hover surface must remain hit-testable in a menu panel"
grep -Fq 'UsageHoverCard(day: hoveredDay)' "$USAGE_DASHBOARD_FILE" \
  || fail "the chart hover state must render exact token details"
grep -Fq 'Hover a bar for exact tokens' "$USAGE_DASHBOARD_FILE" \
  || fail "the chart must visibly advertise its exact-value hover affordance"
grep -Fq 'streakAccent = Color(red: 0.96, green: 0.29, blue: 0.10)' "$USAGE_DASHBOARD_FILE" \
  || fail "the streak badge must use the requested orange-red accent"
grep -Fq '.fill(streakAccent.opacity(0.24))' "$USAGE_DASHBOARD_FILE" \
  || fail "the streak capsule must have a clearly visible orange-red fill"
grep -Fq '.strokeBorder(streakAccent.opacity(0.46), lineWidth: 1)' "$USAGE_DASHBOARD_FILE" \
  || fail "the streak capsule must have a clear orange-red boundary"

PANEL_ENGLISH_FILES=(
  "$PANEL_FILE"
  "$QUOTA_CARD_FILE"
  "$PANEL_HEADER_FILE"
  "$PANEL_FOOTER_FILE"
  "$QUOTA_FORMATTER_FILE"
  "$QUOTA_PRESENTATION_FILE"
  "$QUOTA_STORE_FILE"
)
if grep -Eq '[一-龥，。]' "${PANEL_ENGLISH_FILES[@]}"; then
  fail "status panel strings must be English-only"
fi

echo "PASS [panel-layout] common quotas use the grid and large collections have bounded overflow"

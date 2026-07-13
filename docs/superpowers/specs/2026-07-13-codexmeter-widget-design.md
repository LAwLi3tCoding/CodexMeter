# CodexMeter Menu Bar and Desktop Widget Design

**Date:** 2026-07-13

## Outcome

CodexMeter restores a stable percentage-bearing menu-bar label, formats reset countdowns as compact `d/h/m` values, and ships a native WidgetKit extension that can be placed in Notification Center on macOS 13 and on the desktop on macOS 14 or later.

## User-visible contract

- The menu bar always renders one compact status string after the gauge icon: `Codex 72% · 3h45m`, or `Codex --` while data is unavailable.
- The reset countdown never accumulates days into hours. Examples: `3d2h5m`, `12h4m`, `45m`, `即将重置`, and `—`.
- The widget supports `.systemSmall` and `.systemMedium`.
- The small widget shows the most constrained quota, its percentage, ten-segment gauge, reset countdown, and update freshness.
- The medium widget shows the two most relevant quota windows side by side, with the same semantic colors as the menu panel.
- Quota colors remain exact: `>= 50%` green, `>= 20% && < 50%` orange, `< 20%` red.
- No account email, API token, keychain value, or raw Codex protocol payload is persisted for the widget.

## Root cause and menu-bar repair

The previous working menu-bar implementation rendered the changing status as one text node. The redesign split `Codex` and the percentage/countdown into separate `Text` children. `MenuBarExtra` status-item sizing can keep or truncate those children independently, which matches the observed regression where the brand remained and the percentage disappeared.

`MenuBarPresentation` will expose `displayText`, combining the brand and status into one stable string. `MenuBarLabel` will render exactly one `Text(presentation.displayText)` beside the SF Symbol. This keeps the visual alignment introduced by the redesign while making the percentage indivisible from the brand.

## Countdown rules

The formatter computes positive whole seconds and decomposes them in this order:

1. `days = seconds / 86_400`
2. `hours = (seconds % 86_400) / 3_600`
3. `minutes = (seconds % 3_600) / 60`

When days are present, all three units are rendered (`3d2h5m`). When only hours are present, hours and minutes are rendered (`12h4m`). Under one hour, minutes round up so a future reset never displays `0m`. Existing empty and expired states remain unchanged.

## WidgetKit constraints

WidgetKit extensions are not continuously running processes. Timeline entries are system scheduled and subject to a refresh budget, so a desktop widget cannot promise the menu app's one-minute fetch cadence. CodexMeter therefore uses this honest two-part refresh model:

- The running menu-bar app continues fetching every minute, writes a last-known-good shared snapshot, then requests a timeline reload.
- The widget creates five-minute display entries for the next hour and requests another timeline after the hour. WidgetKit may coalesce or delay those refreshes.

The widget always shows its snapshot update time and marks data stale after 15 minutes. This makes delayed system scheduling visible instead of presenting old values as live.

## Architecture

```text
Codex app-server
      |
CodexProvider -> QuotaStore
      | successful refresh only
      v
WidgetSnapshotPublisher
      | JSON in App Group UserDefaults
      +------------------------------+
      |                              |
WidgetCenter.reloadTimelines         |
                                     v
                        CodexMeterWidget.appex
                        TimelineProvider -> SwiftUI
```

### Shared snapshot

`CodexMeterCore` owns a versioned, Codable, privacy-minimal DTO:

```swift
public struct WidgetQuotaSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let provider: ProviderKind
    public let model: String
    public let updatedAt: Date
    public let quotas: [WidgetQuotaItem]
}
```

Each item includes only `id`, `label`, `model`, `remainingPercent`, `resetTime`, and `windowDurationMinutes`. `WidgetSnapshotStore` reads and writes JSON under the App Group suite. Missing, corrupt, or unsupported-version data produces the widget's empty state. Failed quota fetches never replace the last successful shared snapshot.

### Process boundaries

- `CodexMeterCore` owns DTOs, storage, timeline math, formatting, and presentation logic.
- `CodexMeterApp` owns Codex CLI process lifecycle and the `WidgetCenter` reload bridge.
- `CodexMeterWidget` only reads the shared snapshot. It never starts Codex CLI, accesses Keychain, or performs network requests.

### App Group and identifiers

- App bundle: `com.codexmeter.CodexMeter`
- Widget bundle: `com.codexmeter.CodexMeter.Widget`
- Widget kind: `com.codexmeter.CodexMeter.quota-widget`
- App Group: `group.com.codexmeter.CodexMeter`

Both app and extension carry the App Group entitlement. The main app stays outside App Sandbox because it must launch the user's Codex executable. The widget extension is sandboxed.

## Widget visual design

The widget uses Apple's system widget container, semantic materials, rounded geometry, SF Symbols, monospaced digits, and the existing CodexMeter quota thresholds.

### Small

- Compact `gauge.medium` + `CodexMeter` eyebrow.
- Large percentage for the most constrained quota.
- Quota/window name below the value.
- Ten-segment progress bar.
- Reset countdown and freshness footer.

### Medium

- Header with product name, model, and update status.
- Two equal-width quota columns selected by the existing stable quota display order.
- Each column has label, large percentage, segmented progress, and reset countdown.
- Empty and stale states retain the same layout so the widget does not jump.

## Build and distribution decision

### Chosen for this repository

Keep the existing SwiftPM source of truth and add a WidgetKit executable product. `scripts/build-app.sh` will assemble `CodexMeterWidget.appex` under `CodexMeter.app/Contents/PlugIns`, copy the extension plist, sign the extension with its entitlements first, then sign the containing app.

This is chosen because the machine has Command Line Tools and can compile WidgetKit, but has no full Xcode installation. The build, package, and install scripts must explicitly validate the nested extension so a broken widget cannot silently ship with a working menu app.

### Alternative considered

An Xcode application target plus Widget Extension target is Apple's recommended long-term distribution path and reduces manual bundle/signing risk. It is not selected for this iteration because it cannot be built or verified on the current machine. The shared Core design allows a later migration without changing the widget data contract.

### Rejected alternative

An always-on-top desktop window would refresh freely but is not a macOS widget and would not participate in the widget gallery, desktop placement, tinting, or system lifecycle. It does not satisfy the request.

## Failure handling

- No cached data: show `等待 Codex 数据` and ask the user to open CodexMeter once.
- Corrupt/unknown schema: treat as missing data without crashing.
- Fetch failure: retain the last-known-good snapshot and expose freshness.
- Widget reload throttled: timeline renders countdown changes from cached reset dates and displays stale state.
- Missing/invalid `.appex`: build, package, or install fails before replacing the installed app.

## Verification and acceptance

1. Presentation tests assert the combined menu text includes `Codex`, percentage, and countdown.
2. Formatter tests cover day/hour/minute boundaries and expired/missing reset times.
3. Snapshot tests cover round-trip encoding, privacy, missing/corrupt data, and unsupported schema.
4. Store tests prove only successful quota refreshes publish widget data and failed refreshes retain the last good snapshot.
5. Timeline/presentation tests cover empty, healthy, warning, critical, stale, and two-quota states.
6. The warnings-as-errors Swift build compiles both app and extension.
7. Shell tests validate `.appex` layout, metadata, entitlements, nested signing, release packaging, and installer rejection of malformed widgets.
8. The locally installed app passes `codesign --verify --deep --strict` and `pluginkit` lists `com.codexmeter.CodexMeter.Widget`.
9. A fresh application-window screenshot confirms the menu panel still renders all quota cards without scrolling.

## Platform statement

The application remains macOS 13+. The WidgetKit extension is available in Notification Center on macOS 13; desktop placement requires macOS 14 or later.

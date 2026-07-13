# CodexMeter Design

Date: 2026-07-13

## Product outcome

CodexMeter is a native macOS 13+ menu bar application that shows the most constrained current Codex quota as a remaining percentage and reset countdown, opens a SwiftUI status panel with every available quota window, refreshes once per minute by default, and sends deduplicated low-quota notifications.

Success means:

- the app has no Dock icon and lives only in the menu bar;
- no user-entered token is required;
- account, plan, effective model, quota usage, remaining percentage, and reset time come from the installed Codex CLI;
- absent or newly introduced quota buckets do not crash the UI;
- idle CPU use is negligible;
- the core mapping, notification, formatting, and refresh behavior is covered by tests;
- a local `.app` bundle can be built without third-party dependencies.

## Approaches considered

### A. Persistent Codex App Server client — selected

Launch `codex app-server --listen stdio://`, complete the initialization handshake, and use the documented account and rate-limit methods. This reuses Codex authentication, avoids credential access, supports multiple quota buckets, and gives the cleanest future path to history and live updates. The cost is a long-lived helper process and the need to tolerate protocol evolution.

### B. Session-log and configuration parser

Read the latest rollout JSONL and `config.toml`. This is simple and can work offline, but quota data may be stale until a Codex turn emits another usage event. Session layouts are implementation details, and model/account resolution becomes fragmented. This remains a possible read-only fallback, not the default provider.

### C. Direct ChatGPT backend request

Reuse cached credentials and call an inferred HTTP endpoint. This could return a fresh snapshot with no helper process, but it would require handling secrets and relying on an unsupported private API. This approach is explicitly rejected.

## System architecture

```text
CodexMeterApp
  -> QuotaStore (@MainActor presentation state)
      -> QuotaProvider protocol
          -> CodexProvider
              -> CodexAppServerClient actor
                  -> Codex CLI child process over JSONL stdio
      -> NotificationService
      -> SettingsStore (UserDefaults)
  -> MenuBarExtra
      -> MenuBarLabel
      -> StatusPanelView
          -> QuotaCardView[]
```

Views render immutable state and send user intents back to `QuotaStore`. Process management, JSON decoding, quota calculations, scheduling, notification policy, and persistence stay outside SwiftUI views.

## Project layout

```text
CodexMeter/
├── Package.swift
├── Sources/CodexMeterCore/
│   ├── Models/
│   ├── Providers/
│   ├── Services/
│   ├── Storage/
│   ├── Support/
│   └── State/
├── Sources/CodexMeterApp/
│   ├── App/
│   ├── MenuBar/
│   └── UI/
├── Tests/CodexMeterTests/
├── Resources/Info.plist
├── scripts/build-app.sh
└── docs/
```

Swift Package Manager is the source of truth. `CodexMeterCore` contains importable, platform-facing logic, `CodexMeter` is the thin SwiftUI executable, and the dependency-free `CodexMeterTests` executable runs the core tests even on Command Line Tools installations that do not ship XCTest. The package can be opened directly by Xcode, while `scripts/build-app.sh` assembles the release executable and `Info.plist` into `build/CodexMeter.app`.

## Domain model

`QuotaStatus` represents one quota window, not an entire provider. A provider snapshot contains zero or more statuses so five-hour, weekly, model-specific, and future buckets remain independent.

```swift
struct QuotaStatus: Identifiable, Equatable, Sendable {
    let id: String
    let provider: ProviderKind
    let account: String?
    let model: String
    let limitID: String
    let label: String
    let used: Double
    let remaining: Double
    let percentage: Double
    let resetTime: Date?
    let windowDurationMinutes: Int?
    let updatedAt: Date
}
```

`used` and `remaining` are percentages. `percentage` is the value presented to users and equals the clamped remaining percentage. The explicit properties preserve the requested public model shape while keeping the UI meaning unambiguous.

`ProviderSnapshot` adds provider-wide account, plan, model, and update metadata. Future providers implement the same `QuotaProvider` protocol and map their native responses into these types.

## Data flow

1. App launch creates `QuotaStore` and starts one refresh.
2. `CodexProvider` asks the App Server client for account, effective config, and rate limits.
3. The client starts and initializes the helper on first use, assigns monotonically increasing request IDs, and matches result lines to continuations.
4. The provider prefers `rateLimitsByLimitId`; it uses the single `rateLimits` value only when the multi-bucket view is absent.
5. Each available primary or secondary window becomes one `QuotaStatus`.
6. `QuotaStore` publishes the new snapshot on the main actor and evaluates notifications.
7. If automatic refresh is enabled, an async sleep schedules the next refresh after 60 seconds. It performs no polling work between wakes.

The helper is restarted once after a broken pipe or unexpected exit. Each request has a bounded timeout. Stderr is drained but not persisted.

## Account and model behavior

- ChatGPT account email is masked for display while the full value exists only in memory.
- API-key accounts display “API key account”; no ChatGPT included-quota assumption is made.
- The effective model comes from `config/read` and falls back to a neutral “Codex” label if absent.
- A model-specific quota bucket uses its `limitName` as the card subtitle without replacing the configured-model header.

## Menu bar and panel UI

The menu bar label uses a native SF Symbol plus the minimum remaining percentage. When reset information is available it also shows a compact countdown, for example `72% · 3h45m`. The minimum remaining percentage is intentionally conservative when several windows exist.

The panel is a 360-point-wide SwiftUI window-style `MenuBarExtra`:

- header: app name, masked account, plan, and configured model;
- quota stack: one card per available window, with semantic progress color, remaining percentage, time until reset, and reset clock time;
- state area: loading, actionable error, or no-quota state;
- footer: refresh button, automatic-refresh toggle, last-updated text, and Quit.

Semantic colors and materials provide automatic Dark Mode support. Animations are limited to short value/progress transitions and respect Reduce Motion where practical.

## Notification policy

Thresholds are 50%, 30%, and 10% remaining. A notification is emitted only when a window crosses downward into a new threshold. If the first observation is already low, only the most severe applicable notification is sent. Notifications are keyed by provider, account, limit, window duration, and reset timestamp so relaunching the app does not repeat alerts for the same quota cycle. A new reset cycle clears the effective notification state.

Example body:

```text
Codex quota remaining 15%. Consider switching tasks.
```

Notification authorization is requested through `UNUserNotificationCenter`. Denial never blocks quota display.

## Error handling

User-facing errors are classified:

- Codex CLI not found: show supported installation/path locations;
- Codex not authenticated: ask the user to run the normal Codex login flow, never request a token;
- unsupported or changed protocol: show the installed CLI version and suggest updating CodexMeter or Codex CLI;
- network or service failure: retain the last successful snapshot, mark it stale, and allow manual retry;
- helper process failure: restart once and then surface the error.

Unknown JSON fields and unknown plan strings are ignored or displayed as `unknown`. Missing reset times and window durations produce a reduced card instead of a failure.

## Storage and extension points

`SettingsStore` persists automatic-refresh preference, refresh interval, and notification-cycle state in `UserDefaults`. No credentials are stored.

Future work attaches behind existing boundaries:

- multiple accounts: provider instances and account-scoped storage keys;
- Claude Code, Cursor, Gemini CLI, Copilot: new `QuotaProvider` implementations;
- daily curves: map `account/usage/read` buckets into a separate history repository;
- provider selection: aggregate snapshots in a coordinator without changing cards;
- settings UI: expose provider availability, refresh interval, and notification thresholds.

## Distribution and sandboxing

The initial release is a directly distributed app. App Sandbox is not enabled because CodexMeter must launch the user-installed `codex` executable and communicate with it. This design is not ready for Mac App Store submission. The local build is ad-hoc signed; production release signing and notarization are documented as a release responsibility.

## Test strategy

- model tests: clamping, percentage semantics, window labels, countdown formatting, account masking;
- protocol tests: result/error envelope decoding, multi-bucket response compatibility, optional fields;
- provider tests: multi-bucket preference, primary/secondary mapping, fallback model and account states;
- notification tests: downward crossing, first-observation severity, deduplication, and reset-cycle behavior;
- store tests: initial refresh, manual refresh, auto-refresh preference, stale-data retention;
- build verification: `swift run CodexMeterTests`, `swift build`, release bundle assembly, and `codesign --verify` when available.

## Self-review record

- No credential-reading path is included.
- Multiple quota buckets and missing windows are represented explicitly.
- “Remaining time” is defined as time until reset.
- macOS version, distribution model, refresh interval, and notification thresholds are fixed.
- The design is scoped to a complete local v1; history charts and additional providers remain extension points rather than partially implemented features.

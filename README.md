# CodexMeter

<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="CodexMeter app icon">
</p>

CodexMeter is a native macOS menu bar app that shows the remaining quota reported by the locally installed OpenAI Codex CLI. It uses Swift, SwiftUI, and `MenuBarExtra`, stays out of the Dock, and refreshes without asking users to paste a token.

<p align="center">
  <img src="docs/assets/codexmeter-usage-dashboard.svg" width="460" alt="CodexMeter dashboard showing quota windows, thirty-day token usage, exact hover details, and model insights using example data">
</p>

## What's new in 0.4.1

- Quota alerts at 70%, 50%, 30%, 20%, 10%, 5%, and 1% remaining.
- GUI launches preserve the resolved Codex runtime path so helper discovery matches terminal launches.

## Features

- Compact, always-visible menu bar remaining percentage such as `Codex 64%`.
- Menu bar quota selection prioritizes the advanced Codex model bucket over Spark-specific limits.
- Reset countdowns in the dashboard and widgets use days, hours, and minutes, such as `3d2h5m`.
- Multiple quota windows, including five-hour, weekly, and model-specific limits.
- Compact weekly-quota treatment so long-window status stays visible without dominating the panel.
- Exactly 30 local-calendar days of daily token usage in a native bar chart.
- Today, 7-day, and 30-day token totals with an estimated standard-API equivalent cost in USD.
- Current configured model plus the top model across threads started in the last seven days.
- Seven-day pace, peak-day, and current-streak context alongside the chart.
- Current Codex account type, masked account email, plan, and configured model.
- Manual refresh and a low-CPU automatic refresh loop that defaults to 60 seconds.
- macOS notifications at 70%, 50%, 30%, 20%, 10%, 5%, and 1% remaining, deduplicated per quota cycle.
- Native Dark Mode, Reduce Motion, and VoiceOver support.
- Last-known-good data remains visible during temporary failures.
- Native small and medium WidgetKit widgets for Notification Center and the macOS desktop.
- Provider boundaries for future OpenAI API, Claude Code, Cursor, Gemini CLI, and GitHub Copilot integrations.

## Requirements

- macOS 13 Ventura or later.
- macOS 14 Sonoma or later to place the widget on the desktop. On macOS 13, the widget is available in Notification Center.
- An installed Codex CLI available in `PATH`, `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, or `~/.volta/bin`.
- A Codex CLI account that has completed the normal Codex sign-in flow.
- Swift 5.9 or later to build from source.

CodexMeter never asks for an API key or ChatGPT token.

## Install from GitHub

On an Apple Silicon Mac, install the latest release directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/LAwLi3tCoding/CodexMeter/main/scripts/install.sh | zsh
```

The installer downloads the matching GitHub Release asset and SHA-256 file, verifies the checksum and app signature, and installs `CodexMeter.app` into `/Applications` when writable or `~/Applications` otherwise. It does not require `sudo`, an API key, or a source checkout.

To install a specific release or choose the destination:

```bash
curl -fsSL https://raw.githubusercontent.com/LAwLi3tCoding/CodexMeter/main/scripts/install.sh \
  | CODEXMETER_VERSION=v0.4.1 CODEXMETER_INSTALL_DIR="$HOME/Applications" zsh
```

Then launch CodexMeter:

```bash
open /Applications/CodexMeter.app
```

Launch the containing app once so macOS can discover its widget extension. On macOS 14 or later, Control-click the desktop, choose **Edit Widgets**, search for **CodexMeter**, then add the small or medium widget. The same widget can be added to Notification Center on macOS 13 or later.

Version 0.4.1 provides an Apple Silicon (`arm64`) binary. Intel Macs can build a native binary from source.

## Build from source

```bash
git clone https://github.com/LAwLi3tCoding/CodexMeter.git
cd CodexMeter
./scripts/build-app.sh
open build/CodexMeter.app
```

The script builds the menu app and native WidgetKit extension, embeds `CodexMeterWidget.appex` and the project `LICENSE`, removes release debug metadata that could reveal local build paths, validates both property lists, signs the nested extension first, and applies an ad-hoc local signature to the containing app. Move the app to `/Applications` if desired.

For a debug bundle:

```bash
./scripts/build-app.sh debug
```

## How quota access works

CodexMeter launches two isolated local helper processes, one for quota and one for usage history:

```text
codex app-server --listen stdio://
```

It initializes the documented newline-delimited App Server protocol and uses these read methods:

- `account/read` for the active account type, email, and plan;
- `account/rateLimits/read` for quota windows, usage percentages, and reset times;
- `account/usage/read` for the account token-usage summary and daily usage buckets;
- `config/read` for the effective configured model.

Keeping quota and usage in separate helpers prevents a timeout or restart in one request path from hiding data returned by the other. Both refresh concurrently and retain their own last successful result.

The Network control in the panel can optionally pass a local HTTP(S) proxy to both helpers. For safety it accepts only loopback hosts (`localhost`, `127.0.0.1`, or `::1`) with an explicit port, stores no proxy credentials, and takes effect after CodexMeter restarts.

The app decodes only the fields it needs, ignores unknown response fields, drains helper stderr without storing it, and never reads `~/.codex/auth.json`, Keychain tokens, raw prompt/response bodies, or private ChatGPT HTTP endpoints. Account responses and effective configuration are never logged.

To approximate the top recent model, CodexMeter opens the local Codex `state_5.sqlite` database read-only and aggregates only `model`, cumulative `tokens_used`, and creation timestamps for threads started in the last seven days. It does not read thread titles, working directories, previews, prompts, responses, or credentials. Daily token totals remain sourced from `account/usage/read`; SQLite metadata is used only for this model ranking because the usage response does not include model attribution.

USD values are estimates, not invoices. CodexMeter applies the published OpenAI standard API rates to a documented Codex workload mix of 14% uncached input, 85% cached input, and 1% output. Because the daily service buckets do not include model attribution, all historical tokens are priced using the currently configured model; switching models can make the estimate materially differ from actual API-equivalent cost. Subscription inclusion, Fast mode, long-context uplift, regional processing, tools, credits, taxes, and future pricing changes can also differ. See [OpenAI API pricing](https://developers.openai.com/api/docs/pricing).

Subscription resolution trims blank values and prefers the root quota response, then the canonical `codex` quota bucket, then a plan shared by every other quota bucket. It falls back to account metadata when quota plans are absent or conflicting. The Codex `pro` quota tier is displayed as `PRO 20X`.

`usedPercent` is converted to remaining percentage with `100 - usedPercent`. A value such as `3d2h5m` is the time until that quota window resets; it is not a guaranteed amount of model runtime. The protocol does not provide a reliable remaining-message count.

## Desktop widget refresh behavior

The running menu-bar app continues reading Codex quota data every 60 seconds. After a successful refresh it atomically writes a privacy-minimal snapshot to `~/Library/Application Support/CodexMeter/` and requests a WidgetKit timeline reload. The sandboxed widget has read-only access to that directory; it never starts Codex CLI, reads Keychain, or calls a remote API.

WidgetKit controls the final refresh schedule and may delay or coalesce reload requests. CodexMeter therefore advances countdowns with five-minute timeline entries, shows when its snapshot was updated, and marks data stale after 15 minutes. This is a system-scheduled status widget, not a guaranteed one-minute timer. See Apple's [WidgetKit update guidance](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/) for the platform behavior.

See [the data-source research](docs/research/codex-quota-data-source.md) and [the architecture design](docs/superpowers/specs/2026-07-13-codexmeter-design.md) for details.

## Architecture

```text
CodexMeter
├── Sources/CodexMeterApp
│   ├── App                 SwiftUI app lifecycle and composition
│   ├── MenuBar             Menu bar label
│   ├── Services            Widget snapshot publication bridge
│   └── UI                  Header, cards, states, and controls
├── Sources/CodexMeterCore
│   ├── Models              Quota and presentation models
│   ├── Providers           Codex and future provider boundaries
│   ├── Services            App Server transport and notifications
│   ├── State               Main-actor refresh store
│   ├── Storage             UserDefaults settings and alert state
│   └── Support             Formatting helpers
├── Sources/CodexMeterWidget
│   ├── TimelineProvider    Read-only shared snapshot timeline
│   └── SwiftUI             Small and medium widget layouts
├── Tests/CodexMeterTests   Dependency-free executable test harness
├── Resources               Bundle metadata
└── scripts                 App bundle assembly
```

Views render immutable presentation data and call `QuotaStore` actions. Provider and protocol logic stays in `CodexMeterCore`. `CodexProvider` prefers `rateLimitsByLimitId` and uses the compatibility `rateLimits` value only when the multi-bucket response is absent.

## Development

Run all deterministic tests:

```bash
swift run CodexMeterTests
```

Run the optional integration smoke test against the installed, signed-in Codex CLI:

```bash
swift run CodexMeterTests --suite live
```

Run the independent 30-day usage integration test as well. Direct access is used by default; on a machine that requires a local proxy, provide the same validated loopback URL used by the app:

```bash
CODEXMETER_LIVE_PROXY_URL=http://127.0.0.1:7897 \
  swift run CodexMeterTests --suite live-usage
```

Build with compiler warnings treated as errors:

```bash
swift build -Xswiftc -warnings-as-errors
```

Compile the widget as an app-extension-safe product and validate its assembled bundle:

```bash
swift build --product CodexMeterWidget \
  -Xswiftc -application-extension \
  -Xswiftc -warnings-as-errors
zsh Tests/Scripts/WidgetBundleTests.sh
```

The executable test harness keeps local development compatible with Apple Command Line Tools installations that do not include XCTest or the Swift Testing module.

## Privacy and distribution

- No credentials are stored by CodexMeter.
- Settings contain only refresh preferences, an optional credential-free loopback proxy URL, and notification-cycle state.
- The widget snapshot contains only provider, top-level model, update time, and quota `id`, `label`, `model`, remaining percentage, reset time, and window duration. It excludes account identifiers, plan metadata, and credentials.
- Account identifiers are masked in the UI and are not stored in plaintext notification keys.
- Notification permission denial never blocks quota display.
- App Sandbox is intentionally disabled for the containing menu app because it must locate and launch the user-installed Codex executable. The WidgetKit extension is sandboxed and receives only a read-only file exception for CodexMeter's Application Support directory.
- The release packager rejects app or widget binaries containing local filesystem paths, email addresses, or non-approved internet domains, including when packaging a prebuilt app.

GitHub Release builds are currently ad-hoc signed and checksum-verified, but not signed with an Apple Developer ID or notarized by Apple. macOS may therefore ask for confirmation on first launch. Developer ID signing and notarization are planned for a smoother trust experience. The widget's narrow temporary file exception supports direct GitHub distribution but is not suitable for Mac App Store submission.

Release archives include the canonical MIT license and omit AppleDouble resource-fork metadata. The CodexMeter app icon was created specifically for this project and is distributed under the same MIT License.

## Current limitations

- ChatGPT Codex rate limits are displayed only when the installed CLI exposes them.
- API-key accounts are identified, but OpenAI API billing and organization limits are not implemented.
- Usage history requires a Codex CLI version that exposes `account/usage/read`; quota and usage refresh independently, so either last successful result remains visible when the other endpoint is unavailable.
- The seven-day model ranking compares cumulative tokens in threads started during that period; it is an approximation because the local thread index does not expose turn-level model totals.
- USD values are API-equivalent estimates and are not a replacement for an OpenAI invoice or ChatGPT subscription/credit statement.
- Notifications require launching the assembled `.app` bundle so macOS has a bundle identity.
- Widget updates are scheduled by macOS and cannot guarantee the menu app's one-minute refresh interval.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). By contributing, you agree that your changes are licensed under the project license.

## License

CodexMeter is available under the [MIT License](LICENSE).

CodexMeter is an independent open-source project. It is not affiliated with, endorsed by, or sponsored by OpenAI. OpenAI and Codex are trademarks of their respective owner.

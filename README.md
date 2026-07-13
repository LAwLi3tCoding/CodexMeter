# CodexMeter

CodexMeter is a native macOS menu bar app that shows the remaining quota reported by the locally installed OpenAI Codex CLI. It uses Swift, SwiftUI, and `MenuBarExtra`, stays out of the Dock, and refreshes without asking users to paste a token.

## Features

- Live menu bar percentage and reset countdown.
- Multiple quota windows, including five-hour, weekly, and model-specific limits.
- Current Codex account type, masked account email, plan, and configured model.
- Manual refresh and a low-CPU automatic refresh loop that defaults to 60 seconds.
- macOS notifications at 50%, 30%, and 10% remaining, deduplicated per quota cycle.
- Native Dark Mode, Reduce Motion, and VoiceOver support.
- Last-known-good data remains visible during temporary failures.
- Provider boundaries for future OpenAI API, Claude Code, Cursor, Gemini CLI, and GitHub Copilot integrations.

## Requirements

- macOS 13 Ventura or later.
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
  | CODEXMETER_VERSION=v0.1.0 CODEXMETER_INSTALL_DIR="$HOME/Applications" zsh
```

Then launch CodexMeter:

```bash
open /Applications/CodexMeter.app
```

Version 0.1.0 provides an Apple Silicon (`arm64`) binary. Intel Macs can build a native binary from source.

## Build from source

```bash
git clone https://github.com/LAwLi3tCoding/CodexMeter.git
cd CodexMeter
./scripts/build-app.sh
open build/CodexMeter.app
```

The script builds a release binary, creates `build/CodexMeter.app`, validates its property list, and applies an ad-hoc local signature. Move the app to `/Applications` if desired.

For a debug bundle:

```bash
./scripts/build-app.sh debug
```

## How quota access works

CodexMeter launches one long-lived local helper process:

```text
codex app-server --listen stdio://
```

It initializes the documented newline-delimited App Server protocol and uses these read methods:

- `account/read` for the active account type, email, and plan;
- `account/rateLimits/read` for quota windows, usage percentages, and reset times;
- `config/read` for the effective configured model.

The app decodes only the fields it needs, ignores unknown response fields, drains helper stderr without storing it, and never reads `~/.codex/auth.json`, Keychain tokens, Codex SQLite data, or private ChatGPT HTTP endpoints. Account responses and effective configuration are never logged.

`usedPercent` is converted to remaining percentage with `100 - usedPercent`. A value such as `3h42m` is the time until that quota window resets; it is not a guaranteed amount of model runtime. The protocol does not provide a reliable remaining-message count.

See [the data-source research](docs/research/codex-quota-data-source.md) and [the architecture design](docs/superpowers/specs/2026-07-13-codexmeter-design.md) for details.

## Architecture

```text
CodexMeter
├── Sources/CodexMeterApp
│   ├── App                 SwiftUI app lifecycle and composition
│   ├── MenuBar             Menu bar label
│   └── UI                  Header, cards, states, and controls
├── Sources/CodexMeterCore
│   ├── Models              Quota and presentation models
│   ├── Providers           Codex and future provider boundaries
│   ├── Services            App Server transport and notifications
│   ├── State               Main-actor refresh store
│   ├── Storage             UserDefaults settings and alert state
│   └── Support             Formatting helpers
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

Build with compiler warnings treated as errors:

```bash
swift build -Xswiftc -warnings-as-errors
```

The executable test harness keeps local development compatible with Apple Command Line Tools installations that do not include XCTest or the Swift Testing module.

## Privacy and distribution

- No credentials are stored by CodexMeter.
- Settings contain only refresh preferences and notification-cycle state.
- Account identifiers are masked in the UI and are not stored in plaintext notification keys.
- Notification permission denial never blocks quota display.
- App Sandbox is intentionally disabled in this source build because the app must locate and launch the user-installed Codex executable.

GitHub Release builds are currently ad-hoc signed and checksum-verified, but not signed with an Apple Developer ID or notarized by Apple. macOS may therefore ask for confirmation on first launch. Developer ID signing and notarization are planned for a smoother trust experience; the current design is not ready for Mac App Store distribution.

## Current limitations

- ChatGPT Codex rate limits are displayed only when the installed CLI exposes them.
- API-key accounts are identified, but OpenAI API billing and organization limits are not implemented.
- Usage history and charts are planned extension points, not part of version 0.1.0.
- Notifications require launching the assembled `.app` bundle so macOS has a bundle identity.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). By contributing, you agree that your changes are licensed under the project license.

## License

CodexMeter is available under the [MIT License](LICENSE).

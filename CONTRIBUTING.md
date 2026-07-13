# Contributing to CodexMeter

Thanks for helping improve CodexMeter. Contributions should preserve its small resource footprint, credential-free setup, and native macOS behavior.

## Development setup

1. Use macOS 13 or later with Swift 5.9 or later.
2. Install the Codex CLI for optional live integration tests.
3. Create a focused branch from the current default branch.
4. Build once with `swift build`.

No third-party dependencies are required.

## Change workflow

1. Add or update a failing test for behavior changes.
2. Keep provider, process, persistence, and formatting logic out of SwiftUI views.
3. Prefer existing models and helpers over new abstractions.
4. Never read or log tokens, `auth.json`, Keychain credentials, private configuration payloads, or full account identifiers.
5. Keep changes compatible with macOS 13 unless a version change is explicitly approved.

Run before submitting:

```bash
swift run CodexMeterTests
swift build -Xswiftc -warnings-as-errors
zsh Tests/Scripts/AppIconTests.sh
zsh Tests/Scripts/InstallScriptTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/PanelLayoutTests.sh
zsh Tests/Scripts/WidgetBundleTests.sh
./scripts/build-app.sh
```

Also compile the extension product with app-extension restrictions and warnings as errors:

```bash
swift build --product CodexMeterWidget \
  -Xswiftc -application-extension \
  -Xswiftc -warnings-as-errors
```

If a signed-in Codex CLI is available, also run:

```bash
swift run CodexMeterTests --suite live
```

## Architecture boundaries

- `CodexMeterApp` owns app composition and SwiftUI rendering.
- `CodexMeterCore/Providers` maps provider-native data into domain snapshots.
- `CodexMeterCore/Services` owns process transport and operating-system services.
- `QuotaStore` owns refresh state and is the only observable application state.
- `SettingsStore` may persist preferences and notification metadata, never credentials.
- `AppWidgetSnapshotPublisher` is the only bridge that writes the private Application Support widget snapshot and requests a WidgetKit reload.
- `CodexMeterWidget` reads the privacy-minimal shared snapshot; it must never start Codex CLI, access credentials, or perform network requests.

New coding-tool integrations should implement `QuotaProvider` and must document their supported, non-private data source. Unsupported providers should fail explicitly rather than fabricating quota values.

## Pull requests

Keep pull requests narrow and include:

- a concise problem and solution description;
- tests covering new behavior and failure states;
- exact verification commands and results;
- screenshots for visible UI changes when they can be captured without exposing unrelated private information;
- privacy or compatibility notes for provider/protocol changes.

Do not commit build products, credentials, personal quota data, or generated local state.

## Release packaging

The app version in `Resources/Info.plist` must match the Git tag. Create the GitHub Release assets with:

```bash
./scripts/package-release.sh v0.1.0
```

The command builds and verifies the app plus its nested `CodexMeterWidget.appex`, creates the architecture-specific ZIP in `dist/`, and writes the matching SHA-256 file consumed by `scripts/install.sh`. Upload both files to the same GitHub Release without renaming them.

# CodexMeter Menu Bar and Desktop Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the menu-bar percentage, render reset countdowns with `d/h/m`, and ship a native privacy-safe macOS WidgetKit extension.

**Architecture:** The menu app remains the only process that talks to Codex. Successful `QuotaStore` refreshes publish a versioned snapshot to App Group `UserDefaults`, then request a WidgetKit reload; the extension reads that snapshot and renders small and medium family-specific views from shared Core presentation logic.

**Tech Stack:** Swift 5, SwiftUI, WidgetKit, Combine, Foundation, Swift Package Manager, zsh bundle/signing scripts, App Group UserDefaults.

## Global Constraints

- The application deployment target remains macOS 13.0; desktop widget placement requires macOS 14.0 or later.
- The menu bar renders a single combined text value so `Codex`, percentage, and countdown cannot be independently truncated.
- Countdown output is compact `d/h/m`; a future value under one minute displays `1m`.
- Quota colors are green at 50% or more, orange from 20% through 49.999%, and red below 20%.
- The widget never starts Codex CLI and never persists account, token, keychain, or raw protocol data.
- Widget refresh is best effort under WidgetKit scheduling; the app fetch interval remains one minute.
- No new third-party dependency is introduced.

---

## File map

- `Sources/CodexMeterCore/Models/MenuBarPresentation.swift`: combined status-item copy.
- `Sources/CodexMeterCore/Support/QuotaFormatter.swift`: `d/h/m` countdown decomposition.
- `Sources/CodexMeterCore/Models/WidgetQuotaSnapshot.swift`: versioned privacy-minimal DTO and domain conversion.
- `Sources/CodexMeterCore/Storage/WidgetSnapshotStore.swift`: App Group JSON persistence and publisher protocol.
- `Sources/CodexMeterCore/Models/WidgetQuotaPresentation.swift`: family-independent widget display data and freshness.
- `Sources/CodexMeterCore/Support/WidgetTimelinePolicy.swift`: deterministic five-minute timeline dates.
- `Sources/CodexMeterCore/State/QuotaStore.swift`: successful-refresh publication hook.
- `Sources/CodexMeterApp/Services/WidgetSnapshotPublisher.swift`: App Group write plus WidgetCenter reload.
- `Sources/CodexMeterWidget/*`: WidgetBundle, provider, and small/medium SwiftUI views.
- `Resources/CodexMeter.entitlements`: containing-app App Group entitlement.
- `Resources/CodexMeterWidget.entitlements`: sandboxed extension App Group entitlement.
- `Resources/CodexMeterWidget-Info.plist`: native WidgetKit extension metadata.
- `scripts/build-app.sh`: build, assemble, and nested-sign `.appex`.
- `scripts/package-release.sh` and `scripts/install.sh`: reject malformed extension artifacts.

### Task 1: Stable menu label and `d/h/m` countdown

**Files:**
- Modify: `Tests/CodexMeterTests/MenuBarPresentationTests.swift`
- Modify: `Tests/CodexMeterTests/QuotaFormatterTests.swift`
- Modify: `Sources/CodexMeterCore/Models/MenuBarPresentation.swift`
- Modify: `Sources/CodexMeterCore/Support/QuotaFormatter.swift`
- Modify: `Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift`

**Interfaces:**
- Produces: `MenuBarPresentation.displayText: String`.
- Produces: `QuotaFormatter.countdown(until:now:) -> String` with `d/h/m` output.

- [ ] **Step 1: Write failing presentation and formatter tests**

Add assertions equivalent to:

```swift
expectEqual(presentation.displayText, "Codex 72% · 3h45m")
expectEqual(empty.displayText, "Codex --")

let reset = now.addingTimeInterval((3 * 86_400) + (2 * 3_600) + (5 * 60))
expectEqual(QuotaFormatter.countdown(until: reset, now: now), "3d2h5m")
expectEqual(QuotaFormatter.countdown(until: now.addingTimeInterval(30), now: now), "1m")
```

- [ ] **Step 2: Run the focused suites and verify RED**

Run:

```bash
swift run CodexMeterTests --suite presentation
swift run CodexMeterTests --suite domain
```

Expected: compilation fails because `displayText` is absent, then the day-countdown assertion fails after that property is introduced.

- [ ] **Step 3: Implement the minimal presentation and formatter changes**

Add `displayText` to `MenuBarPresentation` and assign it in both initialization branches:

```swift
public let displayText: String

displayText = "\(brandText) \(labelText)"
```

Decompose reset time with:

```swift
let days = remainingSeconds / 86_400
let hours = (remainingSeconds % 86_400) / 3_600
let minutes = (remainingSeconds % 3_600) / 60

if days > 0 { return "\(days)d\(hours)h\(minutes)m" }
if hours > 0 { return "\(hours)h\(minutes)m" }
return "\(max(1, (remainingSeconds + 59) / 60))m"
```

Render one status text in `MenuBarLabel`:

```swift
Text(presentation.displayText)
    .fontWeight(.semibold)
    .monospacedDigit()
```

- [ ] **Step 4: Run the focused suites and warnings build**

Run:

```bash
swift run CodexMeterTests --suite presentation
swift run CodexMeterTests --suite domain
swift build -Xswiftc -warnings-as-errors
```

Expected: all selected tests pass and build exits 0.

- [ ] **Step 5: Commit the behavior repair**

```bash
git add Sources/CodexMeterCore/Models/MenuBarPresentation.swift Sources/CodexMeterCore/Support/QuotaFormatter.swift Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift Tests/CodexMeterTests/MenuBarPresentationTests.swift Tests/CodexMeterTests/QuotaFormatterTests.swift
git commit -m "fix: restore menu bar quota status"
```

### Task 2: Shared widget snapshot and presentation

**Files:**
- Create: `Sources/CodexMeterCore/Models/WidgetQuotaSnapshot.swift`
- Create: `Sources/CodexMeterCore/Storage/WidgetSnapshotStore.swift`
- Create: `Sources/CodexMeterCore/Models/WidgetQuotaPresentation.swift`
- Create: `Sources/CodexMeterCore/Support/WidgetTimelinePolicy.swift`
- Create: `Tests/CodexMeterTests/WidgetSnapshotTests.swift`
- Create: `Tests/CodexMeterTests/WidgetPresentationTests.swift`
- Modify: `Tests/CodexMeterTests/TestRegistry.swift`

**Interfaces:**
- Produces: `WidgetConfiguration.appGroupID`, `snapshotKey`, and `widgetKind`.
- Produces: `WidgetQuotaSnapshot.init(snapshot:)`, `WidgetSnapshotStore.read()`, and `write(_:)`.
- Produces: `WidgetQuotaPresentation.init(snapshot:now:)` and `WidgetTimelinePolicy.entryDates(start:)`.

- [ ] **Step 1: Write failing snapshot tests**

Cover a successful domain conversion and JSON round trip, and inspect encoded text:

```swift
let widget = WidgetQuotaSnapshot(snapshot: providerSnapshot)
expectEqual(widget.schemaVersion, WidgetQuotaSnapshot.currentSchemaVersion)
expectEqual(widget.quotas.first?.remainingPercent, 72)
try WidgetSnapshotStore(defaults: defaults).write(widget)
let encoded = defaults.data(forKey: WidgetConfiguration.snapshotKey)!
let encodedText = String(decoding: encoded, as: UTF8.self)
expectEqual(encodedText.contains("developer@example.com"), false)
```

Also assert `read()` returns `nil` for missing data, malformed JSON, and a schema version greater than `currentSchemaVersion`.

- [ ] **Step 2: Run the widget suite and verify RED**

Run `swift run CodexMeterTests --suite widget`.

Expected: compilation fails because the widget snapshot and store types do not exist.

- [ ] **Step 3: Implement the DTO and storage boundary**

Define exact constants and DTO fields:

```swift
public enum WidgetConfiguration {
    public static let appGroupID = "group.com.codexmeter.CodexMeter"
    public static let snapshotKey = "widget.quota.snapshot.v1"
    public static let widgetKind = "com.codexmeter.CodexMeter.quota-widget"
}

public struct WidgetQuotaItem: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let model: String
    public let remainingPercent: Double
    public let resetTime: Date?
    public let windowDurationMinutes: Int?
}
```

`WidgetSnapshotStore` must accept injected `UserDefaults`, encode dates as milliseconds since 1970, reject unsupported schema versions, and never delete valid data after a failed write.

- [ ] **Step 4: Write failing widget presentation and timeline tests**

Assert quota ordering, most-constrained selection, colors at 50/20 boundaries, stale state at 15 minutes, and exact dates:

```swift
expectEqual(WidgetTimelinePolicy.entryDates(start: now).count, 13)
expectEqual(WidgetTimelinePolicy.entryDates(start: now)[1], now.addingTimeInterval(300))
```

- [ ] **Step 5: Implement presentation and timeline math**

Expose value-only Core types:

```swift
public struct WidgetQuotaPresentation: Equatable, Sendable {
    public let modelText: String
    public let updatedText: String
    public let isStale: Bool
    public let quotas: [WidgetQuotaItemPresentation]
}
```

Each item supplies percentage, countdown, ten segment fills, and `QuotaLevel`. Timeline dates include `start` and twelve five-minute increments through one hour.

- [ ] **Step 6: Run widget and full Core verification**

Run:

```bash
swift run CodexMeterTests --suite widget
swift run CodexMeterTests
swift build -Xswiftc -warnings-as-errors
```

Expected: all tests pass and build exits 0.

- [ ] **Step 7: Commit the shared widget contract**

```bash
git add Sources/CodexMeterCore Tests/CodexMeterTests
git commit -m "feat: add widget snapshot contract"
```

### Task 3: Publish successful quota refreshes

**Files:**
- Modify: `Sources/CodexMeterCore/State/QuotaStore.swift`
- Modify: `Tests/CodexMeterTests/QuotaStoreTests.swift`
- Create: `Sources/CodexMeterApp/Services/WidgetSnapshotPublisher.swift`
- Modify: `Sources/CodexMeterApp/App/CodexMeterApp.swift`

**Interfaces:**
- Consumes: `WidgetQuotaSnapshot.init(snapshot:)` and `WidgetSnapshotStore.write(_:)`.
- Produces: `WidgetSnapshotPublishing.publish(_:) async` and production `AppWidgetSnapshotPublisher`.

- [ ] **Step 1: Write failing QuotaStore publication tests**

Inject a recording publisher and assert:

```swift
await store.refresh()
expectEqual(await publisher.snapshots(), [snapshot])

await store.refresh() // provider failure
expectEqual(await publisher.snapshots(), [snapshot])
```

- [ ] **Step 2: Run store tests and verify RED**

Run `swift run CodexMeterTests --suite store`.

Expected: compilation fails because `QuotaStore` has no widget publisher injection.

- [ ] **Step 3: Add the publication protocol and success hook**

Use a default no-op implementation so Core callers remain source compatible:

```swift
public protocol WidgetSnapshotPublishing: Sendable {
    func publish(_ snapshot: ProviderSnapshot) async
}
```

Call `await widgetPublisher.publish(newSnapshot)` only after cancellation checks and successful assignment; never call it in the catch branch.

- [ ] **Step 4: Implement the app-side WidgetKit bridge**

`AppWidgetSnapshotPublisher.publish(_:)` converts and writes the snapshot, then calls:

```swift
WidgetCenter.shared.reloadTimelines(ofKind: WidgetConfiguration.widgetKind)
```

Inject this publisher from `CodexMeterApp.makeStore()` for both real and missing provider paths.

- [ ] **Step 5: Verify focused and full builds**

Run:

```bash
swift run CodexMeterTests --suite store
swift run CodexMeterTests
swift build -Xswiftc -warnings-as-errors
```

Expected: tests pass and the app target links WidgetKit successfully.

- [ ] **Step 6: Commit the refresh bridge**

```bash
git add Sources/CodexMeterCore/State/QuotaStore.swift Sources/CodexMeterApp Tests/CodexMeterTests/QuotaStoreTests.swift
git commit -m "feat: publish quota snapshots to widgets"
```

### Task 4: Native WidgetKit extension and interface

**Files:**
- Modify: `Package.swift`
- Create: `Sources/CodexMeterWidget/CodexMeterWidgetBundle.swift`
- Create: `Sources/CodexMeterWidget/CodexMeterQuotaWidget.swift`
- Create: `Sources/CodexMeterWidget/QuotaTimelineProvider.swift`
- Create: `Sources/CodexMeterWidget/QuotaWidgetView.swift`

**Interfaces:**
- Consumes: Widget configuration, snapshot store, presentation, timeline dates, formatter, and quota levels from Core.
- Produces: executable product `CodexMeterWidget` and WidgetKit kind `com.codexmeter.CodexMeter.quota-widget`.

- [ ] **Step 1: Add the executable product and a minimal extension entry**

Update `Package.swift` with an executable product and target depending only on `CodexMeterCore`. Add:

```swift
@main
struct CodexMeterWidgetBundle: WidgetBundle {
    var body: some Widget { CodexMeterQuotaWidget() }
}
```

- [ ] **Step 2: Compile the extension product as app-extension-safe**

Run:

```bash
swift build --product CodexMeterWidget -Xswiftc -application-extension -Xswiftc -warnings-as-errors
```

Expected: `CodexMeterWidget` links as a Mach-O executable without warnings.

- [ ] **Step 3: Implement TimelineProvider**

Use `WidgetSnapshotStore.appGroup()` for production reads. Placeholder uses a fixed two-quota sample; snapshot and timeline read current cached data. Timeline maps `WidgetTimelinePolicy.entryDates(start:)` into entries and returns `.after(lastDate)`.

- [ ] **Step 4: Implement small and medium SwiftUI views**

Use `@Environment(\.widgetFamily)` to branch between focused small and two-column medium layouts. Apply semantic tint from `QuotaLevel`, ten segments from presentation fill values, `.monospacedDigit()`, and `containerBackground(for: .widget)` on macOS 14 with a macOS 13 fallback background.

- [ ] **Step 5: Add widget compilation to full validation**

Run:

```bash
swift build --product CodexMeterWidget -Xswiftc -application-extension -Xswiftc -warnings-as-errors
swift run CodexMeterTests
```

Expected: both commands exit 0.

- [ ] **Step 6: Commit the extension source**

```bash
git add Package.swift Sources/CodexMeterWidget
git commit -m "feat: add native CodexMeter widget"
```

### Task 5: Assemble, sign, package, and install the extension

**Files:**
- Create: `Resources/CodexMeter.entitlements`
- Create: `Resources/CodexMeterWidget.entitlements`
- Create: `Resources/CodexMeterWidget-Info.plist`
- Modify: `scripts/build-app.sh`
- Modify: `scripts/package-release.sh`
- Modify: `scripts/install.sh`
- Create: `Tests/Scripts/WidgetBundleTests.sh`
- Modify: `Tests/Scripts/PackageReleaseScriptTests.sh`
- Modify: `Tests/Scripts/InstallScriptTests.sh`

**Interfaces:**
- Consumes: `CodexMeterWidget` Mach-O product.
- Produces: `CodexMeter.app/Contents/PlugIns/CodexMeterWidget.appex` with valid metadata and nested signatures.

- [ ] **Step 1: Write failing shell fixtures and bundle assertions**

Update fake release apps to include a minimal executable extension and plist. Add negative cases that remove the extension or change `NSExtensionPointIdentifier`; package and install scripts must reject both.

- [ ] **Step 2: Run shell tests and verify RED**

Run:

```bash
zsh Tests/Scripts/WidgetBundleTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/InstallScriptTests.sh
```

Expected: failures report the missing widget bundle validation.

- [ ] **Step 3: Add exact extension metadata and entitlements**

The extension plist must declare `CFBundlePackageType = XPC!`, executable `CodexMeterWidget`, identifier `com.codexmeter.CodexMeter.Widget`, matching `0.1.0 (1)`, minimum macOS 13, and `NSExtensionPointIdentifier = com.apple.widgetkit-extension`.

Both entitlement files declare `group.com.codexmeter.CodexMeter`; only the widget entitlement also declares `com.apple.security.app-sandbox = true`.

- [ ] **Step 4: Assemble and sign nested code in the correct order**

`build-app.sh` builds the extension with `-application-extension`, creates `Contents/PlugIns/CodexMeterWidget.appex/Contents/MacOS`, copies the binary/plist, signs the extension with widget entitlements, then signs the outer app with app entitlements. Verify the extension directly before `codesign --verify --deep --strict` on the app.

- [ ] **Step 5: Harden package and install validation**

Require extension plist and executable, validate bundle ID and extension point with `plutil`, verify extension and app signatures separately, and compare widget/app short versions before packaging or replacing an installed app.

- [ ] **Step 6: Run the shell and real bundle tests**

Run:

```bash
zsh Tests/Scripts/WidgetBundleTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/InstallScriptTests.sh
./scripts/build-app.sh release
codesign --verify --deep --strict --verbose=4 build/CodexMeter.app
```

Expected: every test passes and codesign exits 0.

- [ ] **Step 7: Commit the distribution pipeline**

```bash
git add Resources scripts Tests/Scripts
git commit -m "build: embed and validate widget extension"
```

### Task 6: Documentation, full verification, local install, and delivery

**Files:**
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: completed app bundle and widget extension.
- Produces: documented install/use behavior and verified local/GitHub delivery.

- [ ] **Step 1: Document platform and refresh behavior**

State that desktop placement is macOS 14+, macOS 13 supports Notification Center, the containing app must be launched once, widget refresh is system scheduled, and shared snapshots exclude account/token data. Add the widget build and shell test commands to CONTRIBUTING.

- [ ] **Step 2: Run the full regression matrix**

Run:

```bash
swift run CodexMeterTests
swift build -Xswiftc -warnings-as-errors
swift build --product CodexMeterWidget -Xswiftc -application-extension -Xswiftc -warnings-as-errors
zsh Tests/Scripts/AppIconTests.sh
zsh Tests/Scripts/InstallScriptTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/PanelLayoutTests.sh
zsh Tests/Scripts/WidgetBundleTests.sh
./scripts/build-app.sh release
```

Expected: all Core tests, shell tests, app build, and widget build pass.

- [ ] **Step 3: Install and register locally**

Stop the existing CodexMeter process, replace `/Applications/CodexMeter.app` with the verified release bundle, launch it once, and verify:

```bash
codesign --verify --deep --strict --verbose=4 /Applications/CodexMeter.app
pluginkit -m -A -D -v -i com.codexmeter.CodexMeter.Widget
```

Expected: nested signature passes and pluginkit lists exactly one enabled CodexMeter widget extension.

- [ ] **Step 4: Perform visual and runtime smoke checks**

Confirm the status item displays `Codex <percentage>%`, the panel still shows all quota cards without scrolling, a fresh shared snapshot exists in the App Group suite, and a captured app-window screenshot contains both quota cards.

- [ ] **Step 5: Commit, push, and verify the existing PR**

```bash
git add README.md CONTRIBUTING.md docs/superpowers
git commit -m "docs: explain desktop widget support"
git push origin feature/macos-panel-redesign
gh pr view 1 --json url,headRefOid,mergeable,statusCheckRollup
```

Expected: remote head matches local HEAD and PR #1 remains mergeable with passing checks.

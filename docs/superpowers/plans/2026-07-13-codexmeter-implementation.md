# CodexMeter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS 13+ menu bar app that reads current Codex quota windows through Codex App Server, displays remaining percentages and reset times, refreshes every minute, and sends deduplicated low-quota notifications.

**Architecture:** A SwiftUI `MenuBarExtra` renders state owned by a main-actor `QuotaStore`. `CodexProvider` maps the documented App Server JSONL protocol into provider-neutral models through a long-lived actor client; notification and settings services remain independently testable.

**Tech Stack:** Swift 5.9 language mode, SwiftUI, AppKit, Foundation `Process`, UserNotifications, UserDefaults, Swift Package Manager, and a dependency-free in-repo test executable.

## Global Constraints

- Minimum deployment target is macOS 13.
- The app must not display a Dock icon.
- No user-entered token and no direct credential-file or Keychain reads.
- Default automatic refresh interval is 60 seconds.
- Notification thresholds are 50%, 30%, and 10% remaining.
- Views contain no process, provider, persistence, or quota-calculation logic.
- No third-party runtime or build dependencies.
- Quota countdown text always means time until reset.

---

### Task 1: Package, domain models, and formatters

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexMeterCore/Models/ProviderKind.swift`
- Create: `Sources/CodexMeterCore/Models/QuotaStatus.swift`
- Create: `Sources/CodexMeterCore/Models/ProviderSnapshot.swift`
- Create: `Sources/CodexMeterCore/Support/QuotaFormatter.swift`
- Create: `Tests/CodexMeterTests/TestSupport.swift`
- Create: `Tests/CodexMeterTests/TestRegistry.swift`
- Create: `Tests/CodexMeterTests/TestMain.swift`
- Test: `Tests/CodexMeterTests/QuotaStatusTests.swift`
- Test: `Tests/CodexMeterTests/QuotaFormatterTests.swift`

**Interfaces:**
- Consumes: none.
- Produces: `QuotaStatus`, `ProviderSnapshot`, `ProviderKind`, and pure display formatters used by every later task.

- [ ] **Step 1: Write failing model and formatter tests**

```swift
func testQuotaClampsRemainingPercentage() {
    let quota = QuotaStatus.makeForTest(usedPercent: 125)
    expectEqual(quota.used, 100)
    expectEqual(quota.remaining, 0)
    expectEqual(quota.percentage, 0)
}

func testFiveHourWindowLabel() {
    expectEqual(QuotaFormatter.windowLabel(minutes: 300), "5 小时额度")
}
```

- [ ] **Step 2: Run the targeted tests and confirm RED**

Run: `swift run CodexMeterTests --suite domain`

Expected: compilation fails because the model and formatter types do not exist.

- [ ] **Step 3: Implement the smallest domain model and formatter surface**

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

Use a checked initializer or factory that clamps the server value once and sets `remaining` and `percentage` to `100 - used`.

- [ ] **Step 4: Run the targeted tests and confirm GREEN**

Run: `swift run CodexMeterTests --suite domain`

Expected: all selected tests pass with no warnings.

- [ ] **Step 5: Commit the domain slice**

```text
git add Package.swift Sources/CodexMeterCore Tests/CodexMeterTests
git commit -m "feat: add quota domain model"
```

### Task 2: Codex App Server protocol client

**Files:**
- Create: `Sources/CodexMeterCore/Services/CodexExecutableLocator.swift`
- Create: `Sources/CodexMeterCore/Services/CodexAppServerTransport.swift`
- Create: `Sources/CodexMeterCore/Services/CodexAppServerClient.swift`
- Create: `Sources/CodexMeterCore/Services/CodexProtocolModels.swift`
- Modify: `Tests/CodexMeterTests/TestRegistry.swift`
- Test: `Tests/CodexMeterTests/CodexExecutableLocatorTests.swift`
- Test: `Tests/CodexMeterTests/CodexProtocolDecodingTests.swift`

**Interfaces:**
- Consumes: Foundation `Process` and JSONL protocol.
- Produces: `CodexClientProtocol.account()`, `.rateLimits()`, and `.effectiveConfig()` async methods.

- [ ] **Step 1: Write failing locator and response-decoding tests**

```swift
func testDecodesOptionalSecondaryWindow() throws {
    let data = Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1730947200},"secondary":null}}"#.utf8)
    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: data)
    expectEqual(response.rateLimits.primary?.usedPercent, 25)
    expectEqual(response.rateLimits.secondary, nil)
}
```

- [ ] **Step 2: Run protocol tests and confirm RED**

Run: `swift run CodexMeterTests --suite protocol`

Expected: compilation fails because protocol types and locator are absent.

- [ ] **Step 3: Implement narrow Codable responses and executable lookup**

```swift
protocol CodexClientProtocol: Sendable {
    func account() async throws -> CodexAccountResponse
    func rateLimits() async throws -> CodexRateLimitsResponse
    func effectiveConfig() async throws -> CodexConfigResponse
}
```

The locator searches the current `PATH`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, `~/.local/bin/codex`, and `~/.volta/bin/codex`, accepting only executable regular files.

- [ ] **Step 4: Implement the actor transport**

```swift
actor CodexAppServerClient: CodexClientProtocol {
    private var nextRequestID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    // Start once, initialize, send JSONL requests, match responses, timeout,
    // drain stderr without logging, and restart once after process failure.
}
```

Requests use `account/read`, `account/rateLimits/read`, and `config/read`. Unknown response fields are ignored by `JSONDecoder`.

- [ ] **Step 5: Run protocol tests and confirm GREEN**

Run: `swift run CodexMeterTests --suite protocol`

Expected: all selected tests pass.

- [ ] **Step 6: Commit the protocol slice**

```text
git add Sources/CodexMeterCore/Services Tests/CodexMeterTests
git commit -m "feat: add Codex app server client"
```

### Task 3: Provider mapping, storage, refresh store, and notification policy

**Files:**
- Create: `Sources/CodexMeterCore/Providers/QuotaProvider.swift`
- Create: `Sources/CodexMeterCore/Providers/CodexProvider.swift`
- Create: `Sources/CodexMeterCore/Providers/OpenAIProvider.swift`
- Create: `Sources/CodexMeterCore/Storage/SettingsStore.swift`
- Create: `Sources/CodexMeterCore/Services/NotificationPolicy.swift`
- Create: `Sources/CodexMeterCore/Services/NotificationService.swift`
- Create: `Sources/CodexMeterCore/State/QuotaStore.swift`
- Modify: `Tests/CodexMeterTests/TestRegistry.swift`
- Test: `Tests/CodexMeterTests/CodexProviderTests.swift`
- Test: `Tests/CodexMeterTests/NotificationPolicyTests.swift`
- Test: `Tests/CodexMeterTests/QuotaStoreTests.swift`

**Interfaces:**
- Consumes: `CodexClientProtocol`, domain models, `UserDefaults`, `UNUserNotificationCenter` adapter.
- Produces: `QuotaProvider.fetchSnapshot()`, observable `QuotaStore`, persisted settings, and notification decisions.

- [ ] **Step 1: Write failing multi-bucket provider tests**

```swift
func testProviderPrefersMultiBucketViewAndMapsEveryWindow() async throws {
    let client = StubCodexClient.multipleBuckets()
    let snapshot = try await CodexProvider(client: client).fetchSnapshot()
    expectEqual(snapshot.quotas.map(\.id), ["codex.primary", "codex.secondary", "codex_spark.primary"])
    expectEqual(snapshot.quotas.first?.percentage, 75)
}
```

- [ ] **Step 2: Write failing notification-cycle tests**

```swift
func testInitialLowValueChoosesOnlyMostSevereThreshold() {
    let decision = policy.evaluate(previous: nil, currentRemaining: 8, alreadySent: [])
    expectEqual(decision?.threshold, 10)
}

func testDoesNotRepeatThresholdWithinSameResetCycle() {
    let decision = policy.evaluate(previous: 29, currentRemaining: 25, alreadySent: [30])
    expectNil(decision)
}
```

- [ ] **Step 3: Run provider and policy tests and confirm RED**

Run: `swift run CodexMeterTests --suite state`

Expected: compilation fails because provider, policy, and store types are absent.

- [ ] **Step 4: Implement provider mapping and extension placeholder**

```swift
protocol QuotaProvider: Sendable {
    var kind: ProviderKind { get }
    func fetchSnapshot() async throws -> ProviderSnapshot
}

struct OpenAIProvider: QuotaProvider {
    let kind: ProviderKind = .openAI
    func fetchSnapshot() async throws -> ProviderSnapshot {
        throw ProviderError.notConfigured
    }
}
```

`OpenAIProvider` is an explicit future boundary and is not selected by the app.

- [ ] **Step 5: Implement settings, notification policy, and main-actor store**

```swift
@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: ProviderSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var error: QuotaDisplayError?
    @Published var automaticRefreshEnabled: Bool

    func refresh() async { /* retain last good snapshot on failure */ }
    func startAutomaticRefresh() { /* one cancellable 60-second sleep loop */ }
}
```

- [ ] **Step 6: Run provider, policy, and store tests and confirm GREEN**

Run: `swift run CodexMeterTests --suite state`

Expected: all selected tests pass without duplicate-notification failures.

- [ ] **Step 7: Commit the application-state slice**

```text
git add Sources/CodexMeterCore Tests/CodexMeterTests
git commit -m "feat: add quota refresh and notifications"
```

### Task 4: MenuBarExtra and SwiftUI status panel

**Files:**
- Modify: `Sources/CodexMeterApp/App/CodexMeterApp.swift`
- Create: `Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift`
- Create: `Sources/CodexMeterApp/UI/StatusPanelView.swift`
- Create: `Sources/CodexMeterApp/UI/QuotaCardView.swift`
- Create: `Sources/CodexMeterApp/UI/StatusColor.swift`
- Modify: `Tests/CodexMeterTests/TestRegistry.swift`
- Test: `Tests/CodexMeterTests/MenuBarPresentationTests.swift`

**Interfaces:**
- Consumes: `QuotaStore` and pure formatter/model values.
- Produces: menu-only app entry point and native dark-mode-compatible panel.

- [ ] **Step 1: Write failing presentation-selection tests**

```swift
func testMenuBarUsesMostConstrainedQuota() {
    let state = MenuBarPresentation(quotas: [.remaining(72), .remaining(40)], now: .reference)
    expectEqual(state.percentageText, "40%")
}
```

- [ ] **Step 2: Run presentation tests and confirm RED**

Run: `swift run CodexMeterTests --suite presentation`

Expected: compilation fails because `MenuBarPresentation` is absent.

- [ ] **Step 3: Implement presentation state and views**

```swift
@main
struct CodexMeterApp: App {
    @StateObject private var store = AppContainer.makeQuotaStore()

    var body: some Scene {
        MenuBarExtra {
            StatusPanelView(store: store)
        } label: {
            MenuBarLabel(presentation: store.menuBarPresentation)
        }
        .menuBarExtraStyle(.window)
    }
}
```

Cards show remaining percent, progress, time until reset, and the reset clock. Footer actions call store methods; no view calls a provider directly.

- [ ] **Step 4: Run presentation tests and full debug build**

Run: `swift run CodexMeterTests --suite presentation`

Expected: selected tests pass.

Run: `swift build`

Expected: debug executable builds successfully.

- [ ] **Step 5: Commit the UI slice**

```text
git add Sources/CodexMeterApp Sources/CodexMeterCore Tests/CodexMeterTests
git commit -m "feat: add menu bar quota interface"
```

### Task 5: App bundle, open-source documentation, and end-to-end verification

**Files:**
- Create: `Resources/Info.plist`
- Create: `scripts/build-app.sh`
- Create: `.gitignore`
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `LICENSE`
- Modify: `docs/research/codex-quota-data-source.md`

**Interfaces:**
- Consumes: release executable and app resources.
- Produces: `build/CodexMeter.app`, developer documentation, and installation guidance.

- [ ] **Step 1: Add the bundle contract**

`Info.plist` contains these required values:

```xml
<key>CFBundleIdentifier</key><string>com.codexmeter.app</string>
<key>CFBundleName</key><string>CodexMeter</string>
<key>CFBundleExecutable</key><string>CodexMeter</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
```

- [ ] **Step 2: Implement deterministic bundle assembly**

```sh
swift build -c release
mkdir -p "$APP/Contents/MacOS"
cp "$BINARY" "$APP/Contents/MacOS/CodexMeter"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
```

The script recreates only `build/CodexMeter.app` and never writes into `/Applications`.

- [ ] **Step 3: Write README, contribution guide, license, and architecture links**

README covers requirements, Codex authentication prerequisite, build/run/install commands, privacy behavior, architecture, troubleshooting, and App Store sandbox limitations. CONTRIBUTING covers branch, test, formatting, and pull-request expectations. Use the MIT license.

- [ ] **Step 4: Run the complete verification sequence**

Run: `swift run CodexMeterTests`

Expected: zero test failures.

Run: `swift build`

Expected: debug build exits successfully.

Run: `./scripts/build-app.sh`

Expected: `build/CodexMeter.app` is created and ad-hoc signed.

Run: `codesign --verify --deep --strict build/CodexMeter.app`

Expected: verification exits successfully.

Run: `plutil -lint build/CodexMeter.app/Contents/Info.plist`

Expected: plist reports `OK`.

- [ ] **Step 5: Review requirements and commit the release slice**

Check every product requirement against the design and test output, then commit:

```text
git add .gitignore Package.swift Sources Tests Resources scripts README.md CONTRIBUTING.md LICENSE docs
git commit -m "docs: complete CodexMeter local release"
```

## Plan self-review

- Every design requirement maps to a task and a verification command.
- Interfaces use consistent names across tasks.
- All production behavior begins with a failing in-repo test except generated bundle metadata and documentation.
- The optional OpenAI provider is an explicit unsupported boundary rather than a simulated implementation.
- History charts, multi-account switching UI, and additional coding tools remain outside the v1 implementation while their extension seams are preserved.

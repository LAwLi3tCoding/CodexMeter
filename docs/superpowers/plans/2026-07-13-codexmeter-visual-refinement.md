# CodexMeter Visual Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine CodexMeter into a recognizable, precisely aligned native Codex quota dashboard with a branded menu-bar label, a polished detail panel, segmented quota gauges, and exact green/orange/red thresholds.

**Architecture:** Keep quota classification and menu-bar copy in `CodexMeterCore` presentation models, while SwiftUI views only render prepared values. Preserve the existing non-scrolling two-column panel and add a private segmented gauge inside the quota-card file so no new dependency or public UI abstraction is required.

**Tech Stack:** Swift 5 language mode, SwiftUI, AppKit, `MenuBarExtra`, Swift Package Manager, shell source-contract tests.

## Global Constraints

- Preserve the macOS 13 deployment target and add no dependencies.
- Keep `.menuBarExtraStyle(.window)` and render every quota window without scrolling or disclosure.
- Use system typography, SF Symbols, semantic materials, and semantic system colors for native Dark Mode behavior.
- Classify remaining quota as green at `>= 50`, orange at `>= 20 && < 50`, and red at `< 20`.
- Keep formatting and quota classification out of SwiftUI views.
- Respect Reduce Motion, Differentiate Without Color, and VoiceOver.

---

### Task 1: Lock presentation semantics

**Files:**
- Modify: `Tests/CodexMeterTests/QuotaCardPresentationTests.swift`
- Modify: `Tests/CodexMeterTests/MenuBarPresentationTests.swift`
- Modify: `Sources/CodexMeterCore/Models/QuotaCardPresentation.swift`
- Modify: `Sources/CodexMeterCore/Models/MenuBarPresentation.swift`

**Interfaces:**
- Consumes: `QuotaStatus.percentage`, `QuotaStatus.resetTime`.
- Produces: `QuotaLevel.healthy`, `QuotaLevel.warning`, `QuotaLevel.critical`, `MenuBarPresentation.brandText`, and `MenuBarPresentation.systemImageName`.

- [ ] **Step 1: Write failing boundary and identity tests**

Replace the broad semantic-level fixture with exact boundary assertions:

```swift
let healthy = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 50))
let warningBelowFifty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 50.1))
let warningAtTwenty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 80))
let criticalBelowTwenty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 80.1))

expectEqual(healthy.level, .healthy)
expectEqual(warningBelowFifty.level, .warning)
expectEqual(warningAtTwenty.level, .warning)
expectEqual(criticalBelowTwenty.level, .critical)
```

Add menu-bar identity assertions:

```swift
expectEqual(presentation.brandText, "Codex")
expectEqual(presentation.systemImageName, "gauge.medium")
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift run CodexMeterTests --suite ui-presentation
swift run CodexMeterTests --suite presentation
```

Expected: `ui-presentation` fails at the 20-percent boundary because the existing model returns `.low`; `presentation` fails to compile because `brandText` does not exist.

- [ ] **Step 3: Implement the minimal presentation changes**

Collapse `QuotaLevel` to three cases and implement exact remaining-percentage boundaries:

```swift
public enum QuotaLevel: Equatable, Sendable {
    case healthy
    case warning
    case critical
}

private static func level(for percentage: Double) -> QuotaLevel {
    switch percentage {
    case ..<20:
        return .critical
    case ..<50:
        return .warning
    default:
        return .healthy
    }
}
```

Add the fixed brand string and stable dashboard symbol in `MenuBarPresentation` for both empty and populated states:

```swift
public let brandText: String

brandText = "Codex"
systemImageName = "gauge.medium"
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the two commands from Step 2.

Expected: all `ui-presentation` and `presentation` tests pass.

- [ ] **Step 5: Commit presentation behavior**

```bash
git add Tests/CodexMeterTests/QuotaCardPresentationTests.swift Tests/CodexMeterTests/MenuBarPresentationTests.swift Sources/CodexMeterCore/Models/QuotaCardPresentation.swift Sources/CodexMeterCore/Models/MenuBarPresentation.swift
git commit -m "feat: refine quota presentation semantics"
```

### Task 2: Lock the visual source contract

**Files:**
- Modify: `Tests/Scripts/PanelLayoutTests.sh`
- Test: `Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift`
- Test: `Sources/CodexMeterApp/UI/StatusPanelView.swift`
- Test: `Sources/CodexMeterApp/UI/QuotaCardView.swift`

**Interfaces:**
- Consumes: the SwiftUI source files.
- Produces: a shell contract requiring the branded menu label, 464-point panel width, and segmented quota gauge while preserving no-scroll rendering.

- [ ] **Step 1: Add failing source-contract assertions**

Extend `PanelLayoutTests.sh` with dedicated paths and assertions equivalent to:

```zsh
MENU_BAR_FILE="$ROOT_DIR/Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift"
QUOTA_CARD_FILE="$ROOT_DIR/Sources/CodexMeterApp/UI/QuotaCardView.swift"

grep -Fq '.frame(width: 464)' "$PANEL_FILE" || fail "status panel must use the refined 464-point width"
grep -Fq 'Text(presentation.brandText)' "$MENU_BAR_FILE" || fail "menu bar must identify Codex"
grep -Fq '.monospacedDigit()' "$MENU_BAR_FILE" || fail "menu bar values must not jitter"
grep -Fq 'SegmentedQuotaGauge(' "$QUOTA_CARD_FILE" || fail "quota cards must use the segmented gauge"
if grep -Fq 'ProgressView(value: presentation.progress)' "$QUOTA_CARD_FILE"; then
  fail "quota cards must not use the generic linear progress view"
fi
```

Keep the existing checks that reject scrolling, disclosure, height caps, or dropped quota cards.

- [ ] **Step 2: Run the source-contract test and verify RED**

Run: `zsh Tests/Scripts/PanelLayoutTests.sh`

Expected: FAIL because the panel is still 448 points, the menu bar has no brand text, and the quota card uses `ProgressView`.

### Task 3: Implement the native precision dashboard

**Files:**
- Modify: `Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift`
- Modify: `Sources/CodexMeterApp/UI/StatusPanelView.swift`
- Modify: `Sources/CodexMeterApp/UI/PanelHeaderView.swift`
- Modify: `Sources/CodexMeterApp/UI/QuotaCardView.swift`
- Modify: `Sources/CodexMeterApp/UI/PanelFooterView.swift`

**Interfaces:**
- Consumes: `MenuBarPresentation.brandText`, `MenuBarPresentation.labelText`, `QuotaCardPresentation.progress`, and `QuotaCardPresentation.level`.
- Produces: an aligned branded menu-bar item, a 464-point grouped dashboard, semantic metadata rail, and ten-segment quota visualization.

- [ ] **Step 1: Align and brand the menu-bar label**

Render a fixed-size dashboard symbol, fixed brand, and monospaced live values:

```swift
HStack(alignment: .center, spacing: 5) {
    Image(systemName: presentation.systemImageName)
        .symbolRenderingMode(.hierarchical)
        .frame(width: 14, height: 14, alignment: .center)

    Text(presentation.brandText)
        .fontWeight(.semibold)

    Text(presentation.labelText)
        .monospacedDigit()
}
```

- [ ] **Step 2: Refine the root dashboard surface**

Keep `LazyVGrid`, `ForEach`, and `.fixedSize(horizontal: false, vertical: true)`, change the width to 464 points, replace hard section dividers with spacing and semantic inset surfaces, and retain every loading/error branch.

- [ ] **Step 3: Replace the header metadata grid**

Use `CodexMeter` plus `Codex Usage Dashboard`, a plan capsule, and three equal-width `MetadataItem` values labelled `ACCOUNT`, `MODEL`, and `UPDATED`. Keep the stale-data row below this metadata rail and keep it accessible.

- [ ] **Step 4: Replace the progress view with a segmented gauge**

Implement a private ten-segment view in `QuotaCardView.swift`:

```swift
private struct SegmentedQuotaGauge: View {
    let progress: Double
    let tint: Color
    private let segmentCount = 10

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segmentCount, id: \.self) { index in
                GeometryReader { proxy in
                    Capsule().fill(Color.primary.opacity(0.09))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(tint)
                                .frame(width: proxy.size.width * fillAmount(for: index))
                        }
                }
                .frame(height: 7)
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }

    private func fillAmount(for index: Int) -> Double {
        min(max((progress * Double(segmentCount)) - Double(index), 0), 1)
    }
}
```

Use system green for `.healthy`, orange for `.warning`, and red for `.critical`. Keep symbols and status descriptions so the state is never color-only.

- [ ] **Step 5: Refine typography, spacing, and footer controls**

Use 32-point rounded monospaced percentage text, compact title/model hierarchy, aligned reset metrics, and a subtle semantic accent wash on each card. In the footer, group the automatic-refresh label with the one-minute interval and retain manual refresh and quit controls.

- [ ] **Step 6: Run source-contract and focused tests**

Run:

```bash
zsh Tests/Scripts/PanelLayoutTests.sh
swift run CodexMeterTests --suite ui-presentation
swift run CodexMeterTests --suite presentation
swift build -c release
```

Expected: contract test passes, both focused suites pass, and release build completes without compiler errors.

- [ ] **Step 7: Commit the visual implementation**

```bash
git add Tests/Scripts/PanelLayoutTests.sh Sources/CodexMeterApp/MenuBar/MenuBarLabel.swift Sources/CodexMeterApp/UI/StatusPanelView.swift Sources/CodexMeterApp/UI/PanelHeaderView.swift Sources/CodexMeterApp/UI/QuotaCardView.swift Sources/CodexMeterApp/UI/PanelFooterView.swift
git commit -m "feat: polish Codex quota dashboard"
```

### Task 4: Verify and reinstall

**Files:**
- Modify only if a verification failure exposes a defect.

**Interfaces:**
- Consumes: the completed app and test suite.
- Produces: a verified installed `/Applications/CodexMeter.app` and concise completion evidence.

- [ ] **Step 1: Run the full automated suite**

Run:

```bash
swift run CodexMeterTests
zsh Tests/Scripts/AppIconTests.sh
zsh Tests/Scripts/InstallScriptTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/PanelLayoutTests.sh
swift build -c release
git diff --check
```

Expected: all harness and shell tests pass, the release build succeeds, and `git diff --check` prints no output.

- [ ] **Step 2: Build and install the app**

Run:

```bash
scripts/build-app.sh
scripts/install.sh
open /Applications/CodexMeter.app
```

Expected: one valid CodexMeter process runs from `/Applications/CodexMeter.app`.

- [ ] **Step 3: Perform live smoke verification**

Run:

```bash
swift run CodexMeterTests --suite live
codesign --verify --deep --strict /Applications/CodexMeter.app
pgrep -fl '/Applications/CodexMeter.app/Contents/MacOS/CodexMeter'
```

Expected: live quota fetch passes, signature verification is silent, and exactly one installed process is reported.

- [ ] **Step 4: Review repository state and publish the branch update**

Run:

```bash
git status --short --branch
git log -4 --oneline
git push origin feature/macos-panel-redesign
```

Expected: the worktree is clean and the existing pull request branch contains the visual-refinement commits.

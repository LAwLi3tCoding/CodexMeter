# CodexMeter Panel Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the scrolling CodexMeter detail panel with a compact, all-visible two-column quota dashboard using current native macOS design conventions.

**Architecture:** Extend the pure Core presentation layer with used-quota text and a sorted, lossless quota-card collection. Keep SwiftUI views declarative: the root view owns state branches, the header owns identity metadata, quota cards own visual quota rendering, and the footer owns actions. A shell source-contract test protects the no-scroll requirement that the Core harness cannot observe.

**Tech Stack:** Swift 5 language mode, SwiftUI, AppKit, `MenuBarExtra`, Swift Package Manager, shell contract tests.

## Global Constraints

- Preserve the macOS 13 deployment target and add no dependencies.
- Use `MenuBarExtra` with `.menuBarExtraStyle(.window)`.
- Render every quota window without `ScrollView`, `List`, `DisclosureGroup`, or a maximum-height cap.
- Use standard SwiftUI controls and semantic system colors; do not call macOS 26-only Liquid Glass APIs while building with the macOS 15.5 SDK.
- Keep formatting and ordering logic out of SwiftUI views.

---

### Task 1: Lock quota presentation behavior

**Files:**
- Modify: `Tests/CodexMeterTests/QuotaCardPresentationTests.swift`
- Modify: `Sources/CodexMeterCore/Models/QuotaCardPresentation.swift`

**Interfaces:**
- Consumes: `QuotaStatus.used`, `QuotaStatus.windowDurationMinutes`, `QuotaStatus.limitID`, and the existing `QuotaFormatter` helpers.
- Produces: `QuotaCardPresentation.usedText: String` and `StatusPanelPresentation.quotaCards: [QuotaCardPresentation]`.

- [ ] **Step 1: Write failing tests**

Add assertions that a quota with 22 percent used yields `usedText == "已用 22%"`, includes the used percentage in its accessibility label, and that `StatusPanelPresentation` returns every card sorted by known window duration, limit ID, and ID with unknown durations last.

- [ ] **Step 2: Run the focused harness**

Run: `swift run CodexMeterTests --suite ui-presentation`

Expected: compilation or assertion failure because `usedText` and `quotaCards` do not exist.

- [ ] **Step 3: Implement the presentation fields**

Add `usedText` to `QuotaCardPresentation`, include it in the accessibility label, and build a sorted `quotaCards` array in `StatusPanelPresentation`:

```swift
quotaCards = snapshot.quotas
    .sorted { lhs, rhs in
        let lhsWindow = lhs.windowDurationMinutes ?? .max
        let rhsWindow = rhs.windowDurationMinutes ?? .max
        if lhsWindow != rhsWindow { return lhsWindow < rhsWindow }
        if lhs.limitID != rhs.limitID { return lhs.limitID < rhs.limitID }
        return lhs.id < rhs.id
    }
    .map { QuotaCardPresentation(quota: $0, timeZone: timeZone) }
```

- [ ] **Step 4: Run the focused harness again**

Run: `swift run CodexMeterTests --suite ui-presentation`

Expected: all `ui-presentation` tests pass.

### Task 2: Lock the no-scroll layout contract

**Files:**
- Create: `Tests/Scripts/PanelLayoutTests.sh`

**Interfaces:**
- Consumes: `Sources/CodexMeterApp/UI/StatusPanelView.swift`.
- Produces: an executable source-contract test used by local and CI verification.

- [ ] **Step 1: Add the failing shell test**

The test must reject `ScrollView`, `DisclosureGroup`, and `.frame(maxHeight:)`, and require a 448-point panel and a two-column quota grid.

- [ ] **Step 2: Run the test and verify the existing UI fails**

Run: `zsh Tests/Scripts/PanelLayoutTests.sh`

Expected: failure identifying the current `ScrollView` or height cap.

### Task 3: Rebuild the native status panel

**Files:**
- Modify: `Sources/CodexMeterApp/UI/StatusPanelView.swift`
- Modify: `Sources/CodexMeterApp/UI/PanelHeaderView.swift`
- Modify: `Sources/CodexMeterApp/UI/QuotaCardView.swift`
- Modify: `Sources/CodexMeterApp/UI/PanelFooterView.swift`

**Interfaces:**
- Consumes: `StatusPanelPresentation.quotaCards`, `QuotaCardPresentation.usedText`, and `QuotaStore` actions/state.
- Produces: a 448-point, dynamically sized, non-scrolling menu bar window.

- [ ] **Step 1: Replace the root scrolling stack**

Create one `StatusPanelPresentation` per render, use a two-column `LazyVGrid`, render every `quotaCards` element, remove the 410-point cap, set `.frame(width: 448)`, and finish with `.fixedSize(horizontal: false, vertical: true)`.

- [ ] **Step 2: Rebuild the header**

Use `NSApplication.shared.applicationIconImage`, a system title style, a neutral plan capsule, and a two-column metadata grid for account, model, and update time. Move stale state into a compact warning line.

- [ ] **Step 3: Rebuild the quota card**

Use a low-contrast semantic grouped background with continuous corners. Display one prominent remaining percentage, a native progress view, and compact labels for `usedText`, `countdownText`, and `resetText`. Add `.monospacedDigit()` and retain Reduce Motion and VoiceOver behavior.

- [ ] **Step 4: Compress the footer**

Place automatic refresh, manual refresh, and quit in one row with native controls, help text, accessibility labels, and the existing keyboard shortcut.

- [ ] **Step 5: Run the UI contract and focused tests**

Run:

```bash
zsh Tests/Scripts/PanelLayoutTests.sh
swift run CodexMeterTests --suite ui-presentation
```

Expected: both commands pass.

### Task 4: Verify, package, and reinstall

**Files:**
- Modify only if verification exposes a defect.

**Interfaces:**
- Consumes: the finished Core and SwiftUI changes.
- Produces: a verified `/Applications/CodexMeter.app` running the redesigned panel.

- [ ] **Step 1: Run all automated verification**

Run:

```bash
swift run CodexMeterTests
zsh Tests/Scripts/AppIconTests.sh
zsh Tests/Scripts/InstallScriptTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/PanelLayoutTests.sh
swift build -c release
```

Expected: all harness tests and shell tests pass, and the release build succeeds.

- [ ] **Step 2: Build and install the application**

Run `scripts/build-app.sh`, replace `/Applications/CodexMeter.app` using `scripts/install.sh`, and launch the installed application.

- [ ] **Step 3: Perform visual and accessibility smoke checks**

Confirm the panel has no internal scrollbar, every live quota is visible, account/model/update metadata is readable, controls work, status is not color-only, and the panel remains legible in Dark Mode.

- [ ] **Step 4: Review the final diff**

Run `git diff --check`, inspect the changed files, and confirm no unrelated workspace changes were overwritten.

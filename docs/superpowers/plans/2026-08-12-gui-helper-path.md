# GUI Helper PATH Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CodexMeter reliably launch an npm-installed Codex CLI from a macOS GUI session whose PATH omits Homebrew directories.

**Architecture:** Keep executable discovery unchanged. At the App Server process boundary, prepend the located Codex executable's directory to the child PATH after applying explicit environment overrides, so `#!/usr/bin/env node` can resolve the sibling Node runtime without altering global or npm-managed state.

**Tech Stack:** Swift 5.9, Foundation `Process`, the repository's dependency-free `CodexMeterTests` harness, Swift Package Manager, macOS app bundle scripts.

## Global Constraints

- Preserve existing proxy removal and explicit proxy override behavior.
- Add no dependencies and no user-facing setting.
- Do not modify `/opt/homebrew/bin/codex` or the user's global GUI environment.
- Keep the production change confined to `CodexAppServerClient`.
- Verify both deterministic and live Codex integrations before installation.

---

### Task 1: Lock the GUI PATH Regression

**Files:**
- Modify: `Tests/CodexMeterTests/CodexAppServerClientTests.swift`

**Interfaces:**
- Consumes: `CodexAppServerClient.init(executableURL:requestTimeout:processEnvironment:)`
- Produces: `testExecutableDirectoryIsAddedToChildPath()` regression coverage in the `protocol` suite.

- [ ] **Step 1: Register and write the failing test**

Add a `HarnessTest` named `App Server child can resolve a sibling runtime from a GUI PATH`. Its fake helper should answer `config/read` with `path-ready` only when `dirname "$0"` is an entry in `$PATH`. Construct the client with `processEnvironment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]` and assert that the returned model is `path-ready`.

- [ ] **Step 2: Run the focused suite and verify RED**

Run: `swift run CodexMeterTests --suite protocol`

Expected: the new test fails with `expected "path-ready", got "path-missing"`; existing protocol tests continue to pass.

- [ ] **Step 3: Commit the regression test only**

Run:

```bash
git add Tests/CodexMeterTests/CodexAppServerClientTests.swift
git commit -m "test: reproduce GUI helper PATH failure"
```

### Task 2: Prepend the Located Executable Directory

**Files:**
- Modify: `Sources/CodexMeterCore/Services/CodexAppServerClient.swift`

**Interfaces:**
- Consumes: `executableURL: URL` and the merged child `environment: [String: String]`.
- Produces: a child `PATH` whose first entry is `executableURL.deletingLastPathComponent().path` unless that entry is already present.

- [ ] **Step 1: Implement the minimal PATH normalization**

After merging `processEnvironment`, split the current PATH on `:`, compare entries to the located executable directory, and prepend that directory only when absent. Assign the joined entries back to `environment["PATH"]` before setting `process.environment`.

- [ ] **Step 2: Run the focused suite and verify GREEN**

Run: `swift run CodexMeterTests --suite protocol`

Expected: all protocol tests pass, including `App Server child can resolve a sibling runtime from a GUI PATH`.

- [ ] **Step 3: Run deterministic and compiler verification**

Run:

```bash
swift run CodexMeterTests
swift build -Xswiftc -warnings-as-errors
swift build --product CodexMeterWidget -Xswiftc -application-extension -Xswiftc -warnings-as-errors
zsh Tests/Scripts/WidgetBundleTests.sh
```

Expected: zero test failures, successful builds, and a valid widget bundle.

- [ ] **Step 4: Run live integration under terminal and GUI-like environments**

Run the live and live-usage suites normally, then invoke the built test executable with a sanitized GUI-like PATH. All runs must pass and return non-empty quota or usage data.

- [ ] **Step 5: Commit the implementation**

Run:

```bash
git add Sources/CodexMeterCore/Services/CodexAppServerClient.swift
git commit -m "fix: preserve Codex runtime path for GUI launches"
```

### Task 3: Install, Verify, and Publish

**Files:**
- Generated: `build/CodexMeter.app`
- Replace: `/Applications/CodexMeter.app`
- Preserve: a timestamped backup beside the installed application until verification succeeds.

**Interfaces:**
- Consumes: `scripts/build-app.sh`, the signed-in `/opt/homebrew/bin/codex`, and the patched source.
- Produces: a locally installed patched CodexMeter and a GitHub branch containing the test, fix, design, and plan.

- [ ] **Step 1: Build the release app bundle**

Run: `./scripts/build-app.sh`

Expected: `build/CodexMeter.app` contains a valid app and widget extension with ad-hoc signatures.

- [ ] **Step 2: Preserve and replace the installed application**

Quit CodexMeter, move `/Applications/CodexMeter.app` to a timestamped backup in `/Applications`, copy `build/CodexMeter.app` into `/Applications`, and launch it with `open`.

- [ ] **Step 3: Verify the original symptom is fixed**

Confirm the GUI-launched CodexMeter has a persistent `codex app-server --listen stdio://` child. Confirm `~/Library/Application Support/CodexMeter/quota-snapshot-v1.json` receives a new modification time and contains at least one quota window. Re-run the live suite from `/` with the GUI-like PATH.

- [ ] **Step 4: Commit planning artifacts**

Run:

```bash
git add docs/superpowers/specs/2026-08-12-gui-helper-path-design.md docs/superpowers/plans/2026-08-12-gui-helper-path.md
git commit -m "docs: describe GUI helper PATH fix"
```

- [ ] **Step 5: Push to a fork**

Create or reuse the authenticated user's fork, add it as a `fork` remote, and run `git push -u fork fix/gui-helper-path`. Do not force-push and do not push to `origin`.

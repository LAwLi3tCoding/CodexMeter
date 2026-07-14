# CodexMeter Release Privacy Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove public personal metadata and make every future CodexMeter binary release privacy-clean and MIT-complete.

**Architecture:** Keep bundle assembly in `scripts/build-app.sh` and release policy in `scripts/package-release.sh`. Enforce the policy with real-artifact shell tests, then rewrite public Git identities only after the working tree, bundle, package, and signatures pass fresh verification.

**Tech Stack:** Swift 5.9, SwiftPM, zsh, macOS `strip`, `codesign`, `ditto`, `plutil`, `strings`, Git, GitHub API/CLI.

## Global Constraints

- Preserve macOS 13 compatibility and current app/widget behavior.
- Add no third-party runtime or build dependency.
- Do not publish live account, quota, reset, subscription, machine, or workspace data.
- Keep `LICENSE` as the canonical MIT text.
- Do not publish a GitHub Release or merge the existing pull request in this task.
- Guard every force-push with the previously observed remote SHA.

---

### Task 1: Lock the release privacy and license contract

**Files:**
- Create: `Tests/Scripts/ReleasePrivacyTests.sh`
- Modify: `Tests/Scripts/PackageReleaseScriptTests.sh`
- Modify: `Tests/Scripts/WidgetBundleTests.sh`

**Interfaces:**
- Consumes: `scripts/build-app.sh`, `scripts/package-release.sh`, root `LICENSE`.
- Produces: a real-artifact privacy gate and fixture-level package policy tests.

- [ ] **Step 1: Add the failing real-artifact test**

The script builds and packages `v0.1.0`, then checks:

```zsh
cmp "$ROOT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"
unzip -p "$ZIP" 'CodexMeter.app/Contents/Resources/LICENSE' | cmp "$ROOT_DIR/LICENSE" -
strings -a - < "$APP_EXECUTABLE" | grep -E '(/Users/|/home/|/var/folders/)'
unzip -Z1 "$ZIP" | grep '^__MACOSX/'
```

The path and AppleDouble checks invert the result and fail on any match. Apply the same executable scan to the widget.

- [ ] **Step 2: Add package fixture tests**

Copy root `LICENSE` into successful fake apps. Add cases that remove or alter the bundled license and expect `package-release.sh` to reject them. Assert the successful archive contains the license and no `__MACOSX` entry.

- [ ] **Step 3: Run RED verification**

Run:

```bash
zsh Tests/Scripts/ReleasePrivacyTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
```

Expected: failures report the missing bundled license, embedded build paths, resource-fork metadata, or missing package validation.

---

### Task 2: Sanitize and license the assembled app

**Files:**
- Modify: `scripts/build-app.sh`
- Modify: `Resources/Info.plist`
- Modify: `Resources/CodexMeterWidget-Info.plist`

**Interfaces:**
- Consumes: SwiftPM release executables and root `LICENSE`.
- Produces: a signed app whose executables contain no local build prefix and whose Resources contain the MIT text.

- [ ] **Step 1: Normalize compiler paths**

Append Swift compiler arguments to each build:

```zsh
-Xswiftc -file-prefix-map -Xswiftc "$ROOT_DIR=."
-Xswiftc -debug-prefix-map -Xswiftc "$ROOT_DIR=."
```

- [ ] **Step 2: Strip before signing and install the license**

After copying both executables and before `codesign`:

```zsh
strip -S "$MACOS_DIR/CodexMeter"
strip -S "$WIDGET_MACOS_DIR/CodexMeterWidget"
install -m 644 "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"
```

- [ ] **Step 3: Add bundle copyright metadata**

Add the same non-personal value to both plists:

```xml
<key>NSHumanReadableCopyright</key>
<string>Copyright © 2026 CodexMeter Contributors</string>
```

- [ ] **Step 4: Run focused GREEN verification**

Run:

```bash
zsh Tests/Scripts/WidgetBundleTests.sh
zsh Tests/Scripts/ReleasePrivacyTests.sh
```

Expected: both scripts pass; `codesign --verify --deep --strict build/CodexMeter.app` exits zero.

---

### Task 3: Harden release packaging and open-source documentation

**Files:**
- Modify: `scripts/package-release.sh`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: the sanitized signed app from Task 2.
- Produces: a clean ZIP with no resource forks and documented asset/trademark boundaries.

- [ ] **Step 1: Validate the canonical bundled license**

Before packaging, require the bundled file and compare it byte-for-byte with root `LICENSE`:

```zsh
[[ -f "$APP_DIR/Contents/Resources/LICENSE" ]]
cmp -s "$ROOT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"
```

- [ ] **Step 2: Exclude resource forks**

Replace `--sequesterRsrc` with `--norsrc` in the release `ditto` command.

- [ ] **Step 3: Document rights and verification**

README states that the icon was created for CodexMeter, is distributed under MIT, and that the project is not affiliated with OpenAI. CONTRIBUTING adds the release privacy test to the required command list and prohibits real verification values in PR descriptions.

- [ ] **Step 4: Run package GREEN verification**

Run:

```bash
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/ReleasePrivacyTests.sh
```

Expected: both scripts pass and `shasum -a 256 -c` validates the generated asset.

---

### Task 4: Full regression, install, and independent review

**Files:**
- Verify all modified files.
- Install: `/Applications/CodexMeter.app` from `build/CodexMeter.app`.

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: verified source, package, and local installation ready for publication.

- [ ] **Step 1: Run deterministic tests and strict builds**

```bash
swift run CodexMeterTests
swift build -Xswiftc -warnings-as-errors
swift build --product CodexMeterWidget -Xswiftc -application-extension -Xswiftc -warnings-as-errors
```

- [ ] **Step 2: Run every shell contract**

```bash
zsh Tests/Scripts/AppIconTests.sh
zsh Tests/Scripts/InstallScriptTests.sh
zsh Tests/Scripts/PackageReleaseScriptTests.sh
zsh Tests/Scripts/PanelLayoutTests.sh
zsh Tests/Scripts/WidgetBundleTests.sh
zsh Tests/Scripts/ReleasePrivacyTests.sh
```

- [ ] **Step 3: Install and verify locally**

Stop the running app, copy the verified bundle into `/Applications`, validate its deep signature, and relaunch it. Confirm the installed bundle contains the canonical MIT license and no local build path strings.

- [ ] **Step 4: Obtain independent privacy/code review**

Review the diff for path leaks, license retention, signing order, test bypasses, and scope expansion. Resolve all Critical and Important findings before publishing.

---

### Task 5: Publish clean metadata and rewrite history

**Files:**
- Git metadata for `main`, `feature/macos-panel-redesign`, and local branches.
- Public PR #1 body.

**Interfaces:**
- Consumes: verified commit from Task 4 and the repository-local GitHub `noreply` identity.
- Produces: public branches whose reachable commits expose only the public repository identity.

- [ ] **Step 1: Commit verified changes with the noreply identity**

Stage only scoped files, confirm the staged diff, and commit with a terse privacy-hardening message.

- [ ] **Step 2: Sanitize the PR body**

Replace live values with synthetic text and retain only reproducible verification counts and commands.

- [ ] **Step 3: Create a recoverable pre-rewrite bundle**

Create a Git bundle under `/private/tmp` and record the current remote branch SHAs. Do not place the backup in the repository.

- [ ] **Step 4: Rewrite identities**

Rewrite author and committer name/email on every local branch to the public GitHub identity. Remove `refs/original` after checking the rewritten trees and commit counts.

- [ ] **Step 5: Force-push with leases**

Force-update only public `main` and `feature/macos-panel-redesign`, with explicit expected old SHAs for both refs.

- [ ] **Step 6: Verify public state**

Confirm through fresh fetch and GitHub API that:

```text
all public commit author/committer emails end in @users.noreply.github.com
the PR body contains no exact quota, reset, plan, account, or local runtime values
the PR head matches the local feature branch
GitHub still detects SPDX MIT
no GitHub Release was created
```

- [ ] **Step 7: Remove the temporary backup after remote verification**

Delete the temporary bundle only after both public branch trees and commit counts match their pre-rewrite equivalents.

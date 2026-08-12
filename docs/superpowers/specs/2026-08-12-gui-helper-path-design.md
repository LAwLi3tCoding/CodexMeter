# GUI Helper PATH Fix Design

## Problem

CodexMeter locates a Codex CLI executable at an absolute path and launches it as an App Server helper. A Finder- or login-launched macOS application commonly inherits `PATH=/usr/bin:/bin:/usr/sbin:/sbin`. When the located Codex CLI is an npm launcher such as `/opt/homebrew/bin/codex` with `#!/usr/bin/env node`, the launcher cannot find the adjacent `/opt/homebrew/bin/node`; the helper exits and CodexMeter reports `processUnavailable` as “Unable to read quota.”

The failure is reproducible with the existing live test: it passes under the terminal environment and fails when `PATH` is restricted to the macOS GUI value.

## Goal

Make CodexMeter launch an npm-installed Codex CLI reliably from a normal macOS GUI session without changing the user's Codex CLI installation or globally modifying the GUI environment.

## Considered Approaches

1. Change the npm-managed `/opt/homebrew/bin/codex` launcher to use an absolute Node path. This is small but affects every Codex invocation and can be overwritten by npm.
2. Set a global LaunchServices or `launchctl` PATH. This affects unrelated applications and may not survive logout or restart.
3. Adjust only the App Server child environment inside CodexMeter. This keeps the fix local to CodexMeter and follows the already-established explicit child-environment boundary.

Approach 3 is selected.

## Design

Immediately before launching the App Server process, CodexMeter will ensure that the directory containing the located Codex executable is present at the front of the child process's `PATH`. Existing environment values, proxy sanitization, and caller-provided `processEnvironment` overrides remain intact. Prepending the executable directory lets an `env` shebang locate sibling runtimes such as Node while preserving normal command lookup for the helper.

No new dependency or user preference is introduced. The change is confined to `CodexAppServerClient`.

## Testing

Add a protocol test that launches a fake Codex helper with an explicit GUI-like PATH. The helper reports whether its own executable directory is present in `PATH`. The test must fail before the production change and pass after it.

After the focused test passes, run all deterministic tests, compiler warnings-as-errors builds for the app and widget, and the live Codex integration suites.

## Local Installation and Publication

Build the patched 0.4.0 application, preserve the currently installed application as a recoverable backup, install the patched bundle in `/Applications`, and launch it through LaunchServices. Verification requires a persistent `codex app-server` child and a newly written quota snapshot.

Commit the regression test and production fix on `fix/gui-helper-path`, then push that branch to a GitHub fork. Do not modify the upstream repository directly.

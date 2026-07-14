# CodexMeter Release Privacy and MIT Distribution Design

## Goal

Make the public repository and future GitHub Release artifacts free of personal or corporate identifiers while preserving CodexMeter's existing behavior, installation flow, and MIT licensing.

## Scope

This change covers four publication boundaries:

1. Git commit author and committer metadata on the public `main` and feature branches.
2. Public pull-request text and verification examples.
3. The application and widget executables inside the release ZIP.
4. The MIT license and copyright metadata shipped with the application bundle.

It does not publish a GitHub Release or merge the existing pull request.

## Options considered

### A. Rewrite public history and harden the release pipeline — selected

Replace public commit identities with the repository owner's GitHub-provided `noreply` identity, force-update the two public branches with lease checks, sanitize the PR body, strip release binaries before signing, and add packaging tests. This changes commit hashes but meets the requested privacy boundary without changing repository URLs.

### B. Protect only future commits

Configure `noreply` for new work and leave existing history untouched. This is less disruptive but fails the requirement because existing public Git objects retain the original addresses.

### C. Recreate the repository

Publish a new repository with a squashed clean history. This creates the smallest history but breaks existing URLs and is unnecessary while the repository has no releases or forks.

## Release artifact design

`scripts/build-app.sh` remains the single assembly boundary. It will:

- pass Swift file/debug prefix maps so compiler-owned paths are normalized;
- copy executables into the bundle;
- strip local/debug symbol paths before code signing;
- install the root `LICENSE` at `Contents/Resources/LICENSE`;
- sign the widget and containing app only after all mutations are complete.

`scripts/package-release.sh` will package without resource forks or AppleDouble metadata. The release test contract will reject:

- a missing or modified bundled MIT license;
- `/Users/`, `/home/`, `/var/folders/`, personal email, or corporate-domain strings in either executable;
- `__MACOSX` and AppleDouble entries in the ZIP.

## Repository metadata design

Future commits use the GitHub `noreply` identity configured only for this repository. After code and artifact verification, a local backup bundle is created and every local branch commit is rewritten to the same public repository identity. Only the public `main` and feature branches are force-pushed, each guarded by its previously observed remote SHA.

The pull-request body uses synthetic examples such as `Codex NN%`; it must not include live quota, reset, plan, account, or local installation evidence.

## Licensing and attribution

The canonical root `LICENSE` remains the source of truth. Shipping it inside the app satisfies the MIT notice-retention condition for standalone binary distribution. Both app property lists expose the same non-personal copyright holder through `NSHumanReadableCopyright`.

The README will state that the icon was created specifically for CodexMeter and distributed under the project license. It will also state that CodexMeter is an independent project and is not affiliated with or endorsed by OpenAI.

## Verification

Completion requires all of the following:

- deterministic Swift tests pass;
- warnings-as-errors builds pass for the app and widget;
- bundle, installer, package, icon, layout, and widget scripts pass;
- a fresh release ZIP contains the exact root MIT license;
- raw executable scans contain no local absolute build paths or private domains;
- the ZIP contains no `__MACOSX` entries;
- both app signatures validate after stripping;
- public GitHub commit metadata uses only the configured `users.noreply.github.com` address;
- the public PR body contains no live account or quota values;
- the local installed app is replaced with the verified sanitized build.

## Recovery and limitations

The pre-rewrite Git bundle is kept outside the repository until remote verification succeeds. Force-pushing removes the old commits from active branch and pull-request views, but third-party clones and cached commit URLs cannot be recalled by Git alone. No credentials were exposed, so no secret rotation is required.

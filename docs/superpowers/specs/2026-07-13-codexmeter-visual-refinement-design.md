# CodexMeter Visual Refinement Specification

**Date:** 2026-07-13  
**Status:** Approved by the user's explicit visual-refinement request

## Goal

Turn the existing compact quota window into a recognizable Codex usage dashboard: align the menu-bar identity and live values precisely, make the detail panel easier to scan, replace the generic continuous progress bar with a segmented quota gauge, and apply the requested three-level remaining-quota color system.

## Design direction

The selected direction is a **native precision dashboard**. It keeps the restraint and density of a macOS utility while giving CodexMeter one memorable visual motif: a segmented quota rail repeated consistently across the dashboard.

Two alternatives were considered and rejected:

1. **Dense table:** maximizes information density, but makes the panel feel like diagnostics instead of a polished menu-bar utility.
2. **Decorative glass dashboard:** adds stronger visual effects, but competes with the quota data and cannot be implemented consistently on the macOS 13 deployment target.

The selected direction uses system typography, semantic surfaces, SF Symbols, subtle depth, and precise spacing. This is intentionally native rather than web-like; San Francisco and platform controls are the correct typography and interaction system for this app.

## Menu-bar identity

- Show a dashboard-style SF Symbol, the fixed word `Codex`, and the live quota value as one vertically centered label.
- Separate the fixed brand and dynamic value with deliberate spacing so the text no longer appears attached to the icon.
- Use monospaced digits for percentage and countdown values so minute-by-minute changes do not shift the label.
- Keep the label compact: `Codex 72% · 3h45m`. The word `Codex` makes the status item self-identifying even when several menu-bar utilities are installed.
- Preserve a concise VoiceOver label that explains remaining quota and reset time.

## Panel composition

- Preserve the non-scrolling, two-column quota dashboard and render every quota window.
- Increase the panel width slightly from 448 to 464 points to give numbers, reset time, and metadata a stable baseline without increasing height.
- Replace hard divider-led sections with a single grouped dashboard surface and spacing-led hierarchy:
  - identity header;
  - compact metadata rail;
  - quota grid;
  - subdued control footer.
- Keep loading, empty, stale, and failure states visually consistent with the dashboard surface.

## Header

- Use the packaged application icon as the primary identity mark.
- Pair `CodexMeter` with the descriptor `Codex Usage Dashboard` so the panel purpose is explicit.
- Keep the plan as a compact trailing capsule.
- Present account, model, and updated time as three aligned metadata items with small uppercase-style labels and stronger values. This removes the current loose icon-label grid and improves scan order.
- Show stale-data failure as a compact amber inset row below metadata.

## Quota cards

- Each card uses three reading layers:
  1. window title and semantic state symbol;
  2. large remaining percentage with the word `remaining`/`剩余` subordinated;
  3. a 10-segment quota rail followed by used, reset countdown, and absolute reset time.
- Use rounded monospaced digits for large percentages and countdowns.
- Use a subtle accent wash inside each card instead of a colored outline. The card remains legible in both light and dark appearances.
- The segmented rail fills from left to right according to remaining quota. Empty segments stay neutral, which makes the proportion readable without depending on color alone.
- Status symbols and accessibility descriptions continue to supplement the color encoding.

## Semantic color thresholds

The color rules are based on remaining percentage and have exact boundary behavior:

- `percentage >= 50`: healthy, system green;
- `20 <= percentage < 50`: warning, system orange;
- `percentage < 20`: critical, system red.

There is no fourth visual color. The existing low/critical distinction is collapsed in the presentation model so `20%` is orange, `19%` is red, and `50%` is green.

## Motion and accessibility

- Animate only percentage and segment-fill changes with a short ease-out transition.
- Disable those transitions when Reduce Motion is enabled.
- Respect Differentiate Without Color by using explicit checkmark, warning, and critical symbols.
- Keep all quota content as a single accessible summary per card and keep buttons individually accessible.
- Use semantic system colors and materials so Dark Mode and increased contrast remain supported.

## Architecture

- `MenuBarPresentation` owns all status-item strings and the dashboard symbol name.
- `QuotaCardPresentation` owns quota-level classification; SwiftUI does not recalculate thresholds.
- `MenuBarLabel`, `PanelHeaderView`, `QuotaCardView`, and `PanelFooterView` remain focused on rendering.
- A new private segmented-gauge view lives beside `QuotaCardView`; it accepts only normalized progress, semantic color, and accessibility state.
- Source-contract tests protect the fixed-width, two-column, no-scroll layout and the use of a segmented gauge.

## Acceptance criteria

1. The menu-bar item visibly identifies Codex and keeps its icon, brand, percentage, and countdown aligned.
2. The panel purpose is explicit from the header and all account/model/update metadata is aligned and readable.
3. Quota cards use a 10-segment remaining-quota rail rather than the generic linear `ProgressView`.
4. Remaining quota is green at 50% and above, orange from 20% through values below 50%, and red below 20%.
5. Every quota window remains visible without scrolling or disclosure.
6. Dark Mode, Reduce Motion, Differentiate Without Color, VoiceOver summaries, refresh controls, and error states remain supported.
7. Presentation tests, layout source-contract tests, the full test harness, and a release build pass.

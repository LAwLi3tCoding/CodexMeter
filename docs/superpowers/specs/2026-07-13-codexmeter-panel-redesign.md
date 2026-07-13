# CodexMeter Panel Redesign Specification

**Date:** 2026-07-13
**Status:** Superseded by the [CodexMeter Visual Refinement Specification](2026-07-13-codexmeter-visual-refinement-design.md)

This document records the earlier redesign direction. The linked specification is the current source of truth, including its bounded overflow fallback for collections larger than four quota cards.

## Goal

Redesign the CodexMeter menu bar window so every quota window is visible at a glance without an internal scroll view or disclosure control, while matching current native macOS visual language and preserving the existing macOS 13 deployment target.

## Evidence and constraints

- The existing `StatusPanelView` wraps quota cards in a `ScrollView` capped at 410 points and fixes the panel at 360 points wide. This creates avoidable scrolling and compresses account/model metadata.
- The provider can return more than the two canonical windows. A two-column grid must therefore grow vertically and retain every quota instead of truncating the collection.
- `QuotaStatus.used` already exists, but the current presentation omits it while repeating the remaining percentage.
- The local machine runs macOS 26.5, but the installed SDK is macOS 15.5. New macOS 26-only Liquid Glass APIs cannot be compiled safely. Standard SwiftUI controls and semantic materials remain the compatibility path.

Apple's current guidance supports this direction:

- [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra) recommends the window style for data-rich menu bar content.
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/) recommends presenting more content in fewer nested levels while maintaining comfortable density.
- [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers/) recommends making transient surfaces only large enough for their related information and actions.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) and [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/) favor system text styles, sufficient contrast, semantic hierarchy, and non-color-only status communication.

## Considered layouts

### 1. Compact full-width rows

Each quota occupies one wide row. This is highly readable but wastes horizontal room and becomes tall when Codex returns three or four windows.

### 2. Two-column dashboard grid — selected

Quota cards appear in a two-column adaptive grid. The canonical 5-hour and weekly windows appear side by side, three or four windows use two rows, and the panel grows vertically without an internal scroll view. This offers the best balance of scanability, density, and native dashboard structure.

### 3. Hero quota with collapsed details

One quota is emphasized and other windows are hidden behind disclosure. This violates the requirement that all quota information be visible immediately.

## Layout

- Panel width: 448 points.
- Root layout: fixed vertical content using `VStack`; no `ScrollView`, `List`, `DisclosureGroup`, or height cap.
- Header:
  - 32-point packaged application icon.
  - `CodexMeter` title and plan badge.
  - Account, current model, and update time in a compact metadata grid.
  - Stale-data state appears as a compact warning line, not a separate tall banner.
- Quota dashboard:
  - Two flexible equal-width columns with a 10-point gap.
  - Every quota from `StatusPanelPresentation.quotaCards` is rendered.
  - Each card shows window name, model where it differs, remaining percentage, native progress indicator, used percentage, relative reset countdown, and absolute reset time.
  - Percentage and time values use monospaced digits to avoid visual jitter during refresh.
- Footer:
  - One compact row containing the native automatic-refresh toggle, manual refresh action, and quit action.
  - No duplicated update timestamp.

## Visual system

- Use system fonts, SF Symbols, semantic colors, and continuous rounded rectangles.
- Use one low-contrast grouped surface per quota card; remove colored outlines and stacked material layers.
- Use the app accent color for healthy quotas. Reserve orange and red for low and critical states.
- Always pair warning colors with a symbol and accessible text.
- Standard `Button`, `Toggle`, and `ProgressView` controls remain responsible for platform-native appearance, including future system styling when built with a newer SDK.
- Support Dark Mode, Increase Contrast, Reduce Transparency, Reduce Motion, and VoiceOver through semantic styles and accessibility labels.

## Presentation model

`QuotaCardPresentation` adds:

- `usedText`: formatted as `已用 22%`.
- An accessibility label containing both used and remaining percentages.

`StatusPanelPresentation` adds:

- `quotaCards`: every quota converted to presentation data.
- Stable display ordering by known window duration, then limit ID, then quota ID. Unknown durations sort last.

Views consume presentation values and do not format quota data themselves.

## Acceptance criteria

1. `StatusPanelView` contains no internal scroll view, disclosure view, or quota height cap.
2. Two canonical quotas are visible side by side; three or four quota windows are all visible in additional rows.
3. No quota returned by the provider is dropped.
4. Each quota shows remaining, used, relative reset, and absolute reset information.
5. Account, model, plan, and last update remain visible without a disclosure action.
6. Existing refresh, auto-refresh, quit, loading, empty, error, stale-data, Dark Mode, and reduced-motion behavior continues to work.
7. Core tests, UI source-contract tests, script tests, and a release build pass.

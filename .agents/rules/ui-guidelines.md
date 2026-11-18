# UI & Design System Guidelines

All presentation layer code in ShortsSplitter must adhere strictly to these UI/UX design standards.

## 1. Design Tokens (Zero Magic Numbers)
Never hardcode raw numbers for layout spacing, corner radii, shadows, or animation durations in widgets.
Always use `AppTokens` (`lib/app/theme/app_tokens.dart`):
- **Spacing Scale:**
  - `AppTokens.spaceXs` (4dp)
  - `AppTokens.spaceSm` (8dp)
  - `AppTokens.spaceMd` (12dp)
  - `AppTokens.spaceLg` (16dp)
  - `AppTokens.spaceXl` (24dp)
  - `AppTokens.spaceXxl` (32dp)
- **Border Radii:** `AppTokens.borderRadiusSm` (8dp), `borderRadiusMd` (12dp), `borderRadiusLg` (16dp), `borderRadiusXl` (24dp), `borderRadiusFull` (999dp).
- **Elevations:** `AppTokens.elevationNone` (0), `elevationSm` (1), `elevationMd` (3), `elevationLg` (6).
- **Durations:** `AppTokens.durationFast` (150ms), `durationNormal` (250ms), `durationSlow` (400ms).

## 2. 14 Mandatory Reusable Shared Widgets
Always reuse existing components in `lib/shared/widgets/` instead of rolling custom implementations:
1. `AppScaffold`: Adaptive navigation wrapper (NavigationBar on phones, NavigationRail on tablets/landscape).
2. `SectionCard`: Elevated grouping card with header, optional action, and standardized padding.
3. `PrimaryButton`: Full-width or inline filled action button with loading and disabled states.
4. `SecondaryButton`: Outlined action button for secondary actions.
5. `StatTile`: Metric display widget for activity figures, clip counts, and storage.
6. `EmptyState`: Centered placeholder with icon, title, description, and action button.
7. `ErrorState`: Error graphic, message, and retry button.
8. `LoadingSkeleton`: Pulsing placeholder matching card and tile shapes.
9. `ProgressRing`: Radial progress indicator with animated percentage and status label.
10. `InfoBanner`: Notice banner with info, warning, and error status types.
11. `ClipTile`: Formatted clip row with preview, open file, and delete actions.
12. `ColorPickerField`: Color swatch picker for canvas backgrounds and overlays.
13. `SettingsTile`: Standardized settings entry with icon, title, subtitle, and trailing control.
14. `ConfirmDialog`: Unified confirmation dialog for destructive actions (e.g., delete, discard, cancel export).

## 3. Four Mandatory Screen States
Every screen consuming asynchronous data must handle all four states explicitly via Riverpod's `AsyncValue.when(...)`:
- **Loading:** Display `LoadingSkeleton` (e.g. `LoadingSkeleton.card()`, `LoadingSkeleton.tile()`).
- **Empty:** Render `EmptyState` with a helpful icon and actionable next step.
- **Error:** Render `ErrorState` with user-friendly error message and `onRetry` callback.
- **Content:** Render final layout wrapped in `RefreshIndicator` where appropriate.

## 4. Adaptive Navigation & Breakpoints
- **Compact (< 600dp):** Phone layout using bottom `NavigationBar` with 4 primary destinations (Dashboard, Create, History, Settings).
- **Expanded (>= 600dp):** Tablet and landscape orientation using vertical `NavigationRail` alongside content.

## 5. Accessibility & Motion
- **Touch Targets:** All interactive elements must maintain a minimum touch target size of 48x48dp (`AppTokens.minTouchTarget`).
- **Contrast:** Ensure all text passes WCAG AA contrast (4.5:1 for normal text, 3:1 for large text).
- **Reduced Motion:** Check `MediaQuery.maybeDisableAnimationsOf(context)` before starting repeating animations.
- **Font Scaling:** Support text scaling up to 200% without clipping or overflowing cards.

## 6. Code Hygiene & Size Invariants
- **File Length:** Every file must remain under 300 lines of code. Split complex screens into private or domain sub-widgets.
- **Method Length:** The `build()` method must never exceed 100 lines. Extract sub-sections into private helper methods (`_buildHeader()`, `_buildList()`).


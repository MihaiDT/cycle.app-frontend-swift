# DesignSystem — Tokens, components, glass surfaces

## Typography

- Reach for `AppTypography` tokens (`Tokens/Typography.swift`) before writing one-off `.raleway(family:size:relativeTo:)`. Raleway is the only family — there is no fallback.
- Available weights bundled in `CycleApp/Resources/Fonts/`: `Thin, ExtraLight, Light, Regular, Medium, SemiBold, Bold, ExtraBold, Black` plus matching `*Italic` variants. Defaults reach for `Regular, Medium, SemiBold, Bold`; only use the heavier (`Black`) or italic faces when a token explicitly calls for them (e.g. `statDisplay`, `heroDisplay`).
- `.tracking(...)` is reserved for **caps eyebrows** (1.0–1.4) and large display numerals (-0.4 to -1.2). Don't track body copy.
- Token roles (use a token before introducing a new size):
  - **Card titles** — `cardTitlePrimary` (20pt, editorial section markers), `cardTitleSecondary` (22pt, mid-density widgets), `cardTitleTertiary` (17pt, inner-section / dense tiles).
  - **Card label** — `cardLabel` (14pt SemiBold, inline label paired with a numeric value).
  - **Eyebrow** — `cardEyebrow` (11pt SemiBold UPPERCASE) + `cardEyebrowTracking` (1.2). Use for caps category labels.
  - **Display** — `heroDisplay` (30pt BoldItalic, modal hero quotes / pull-phrases) + `heroDisplayTracking` (-0.4); `statDisplay` (36pt Black, big numeric pull-stats) + `statDisplayTracking` (-0.8).
  - **Modal header** — `modalHeader` (15pt Bold, sheet/modal date or title rows).
  - **Body** — `bodyMedium` (13pt Medium, descriptive copy and empty-state hints inside cards/modals).

## Layout tokens

- `AppLayout.screenHorizontal` (14pt) — feed/list screens (Today, Cycle Stats, Cycle Detail, Cycle Journey, Profile). The "editorial column" gutter.
- `AppLayout.horizontalPadding` (32pt) — ritual/focus screens (Onboarding, MoodArc, DailyCheckIn, Challenges).
- **Don't mix.** Picking the wrong gutter is the #1 way to make a new screen feel out-of-app.
- Spacing scale: `spacingXS=4, S=8, M=16, L=24, XL=32, XXL=48`. Card stacks (Cycle Stats, Cycle Detail) use `spacingL` (24) between cards.

## `widgetCardStyle` contract

- Owns fill + clip + shadow + glass. **NEVER** pair with `.background(.ultraThinMaterial)` or an outer `.clipShape(...)` — it doubles the glass pass and was the dominant scroll cost on iOS 26.
- Parameters:
  - `cornerRadius` — 28 on Cycle Stats / Cycle Detail screen cards, 24 on explainer-sheet sections, 22 on small tiles (`StatRingTile`).
  - `rasterize` — `false` for cards embedding UIKit-backed views (`Picker(.segmented)`, Swift Charts, `UIViewRepresentable`). Metal flattening can't render those subtrees and falls back to a yellow placeholder.
  - `interactive` — `true` (default) gives Liquid Glass press ripple. `false` for cards with internal motion that competes with the touch shader (charts, sliding detail blocks).
- iOS 26+ uses native `.glassEffect(.regular, in: shape)` (or `.regular.interactive()`). Pre-iOS 26 falls back to `drawingGroup(opaque: false) + .background(Color.white) + .clipShape(shape)`.

## Animation in shared components

- Shared visualization components (`TrendBarChart`, `GlossyBar`, `StatRingTile`, etc.) **MUST NOT** use scoped `.animation(value:)`. Scoped animations override the host's transaction (including `disablesAnimations` on cell reuse), so the host can't seed values silently.
- Expose the value, let the host wrap the change in `withAnimation { ... }`. The component renders whatever state it's given, statically.
- Exception: `.contentTransition(...)` is fine — it only fires when the host's animation context provides one, same as `.transition(...)`.

## Color usage

- `DesignColors.text` — primary editorial color. `.textSecondary` — muted labels, captions.
- `.textSecondary.opacity(0.7)` — chart axis labels.
- `.textSecondary.opacity(0.55)` — chevron drill-in indicators on tappable cards.
- `.accentWarm` (terracotta) — in-range / typical / good. `.accentHoney` — needs attention / outside range.
- `.statusSuccess` — confirmation tone (used sparingly; the warm/honey pair carries most state).
- All colors are dark-mode-aware via the asset catalog; don't hardcode hex.

## CTA buttons — pick the right family

- `GlassButton` (Liquid Glass, white-translucent capsule) — onboarding/ritual primary CTAs (Begin / Continue / Next / Done).
- `HeroGlassCapsuleButton` (white-glass capsule, soft) — secondary affordances over warm hero gradients and editorial card surfaces. Layouts: `.small`, `.compact`, `.large`, `.wide`.
- `GlowPrimaryButton` (dark cocoa, full-width, cream arrow badge) — single dominant action on Daily Glow detail screens.
- `WarmCapsuleButton` (`accentWarm → accentSecondary` gradient capsule with gloss) — period-editing CTAs and warm empty-state actions across Calendar surfaces. Prominences: `.compact` (h22/v10), `.primary` (h26/v14); supports optional leading SF Symbol icon and `isFullWidth`.
- One-off allowed: `AriaPromptOverlay`'s "Talk to Aria" button uses `accentWarm → .accent` (not `.accentSecondary`). Deliberate Aria-context tint, not a migration target.

## Component organization

- `Components/Buttons/` — `AppCloseButton`, `AppDoneButton`, `WarmCapsuleButton`. `GlassToolbar.swift` exposes a `.glassToolbar()` no-op modifier (hook for future iOS 26 Liquid Glass).
- `Components/Cards/` — surface modifiers (`WidgetCardStyle`).
- `Components/Controls/` — interactive primitives (`GlassButton`, `HeroGlassCapsuleButton`, `WarmCapsuleButton`, `GlowPrimaryButton`, glass form controls).
- `Components/Hero/` — large display elements (cycle hero, journey hero).
- `Components/Layout/` — backgrounds (`AppleHealthBackground`, `JourneyAnimatedBackground`).
- `Components/Tiles/` — small repeating tiles.
- `Components/Visualizations/` — charts, rings, bars.
- `Components/Widgets/` — composed widget cards.
- `Components/Brand/` — brand-specific elements.

When adding a new component, drop it in the folder by **role**, not by feature. Cycle stats / journey / today don't get their own DesignSystem folders.

## Don't

- Don't add `import` statements for internal modules (`import Models`, `import Persistence`, `import CycleEngine`, etc.). Flat compilation: everything compiles into one CycleApp target via XcodeGen.
- Don't ship a new visual primitive without a Preview that exercises at least 2 states (default + an edge case).
- Don't write component-level animations against `.spring(response: 0.42, dampingFraction: 0.86)` literals — they're the app-wide spring profile; if there's no shared token yet, define one before the second copy.

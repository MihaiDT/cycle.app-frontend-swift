# CycleInsights — Cycle Stats / Cycle Detail surface

## Folder layout

Files are organized by **role**, not by relatedness. Don't drop a screen, dialog, layout helper, or sub-component into `Cards/` "because it's part of the trend story" — `Cards/` is a strict subset.

- `Cards/` — full cards rendered on Cycle Stats (one per `CycleStatsCard` enum case). Each owns a `widgetCardStyle`. Sub-folder `BodySignals/` holds the BodySignals card's internal Components/States/Support folders.
- `Components/` — sub-pieces of cards that aren't standalone cards: detail blocks (`CycleTrendDetailBlock`), invite blocks (`CycleTrendInviteBlock`), row entries (`CycleHistoryEntry`), timeline visualizations (`CycleHistoryTimeline`), skeleton variants (`CycleInsightsSkeletons`), shared UI bits (`CycleInsightsComponents`).
- `Screens/` — full views pushed on the inner `NavigationStack`: `CycleDetails.swift`, `CycleHistoryAll.swift`. Not cards, not sheets.
- `Sheets/` — modal sheets / fullScreenCover surfaces (stat-info detail, customize layout, share screen, BodySignals detail).
- `Layout/` — UIKit-backed scroll containers and hosting wrappers (`CycleStatsCardList`).
- `Dialogs/` — confirm/action modals (`HideCycleDialog`).
- `Models/` — feature-local types.
- Root: `CycleInsightsFeature.swift` (reducer), `CycleInsightsView.swift` (root view), `CycleInsightsView+Cards.swift` (view extensions).

When adding a new file, name its role first. New cards go in `Cards/`, new sub-pieces in `Components/`, new pushed screens in `Screens/`, etc.

## Hosting & scroll

- Cards are hosted in `CycleStatsCardList` (UIKit `UICollectionView` + `UIHostingConfiguration`), **NOT** SwiftUI `ScrollView` or `List`. Profiling on iOS 26 showed `AttributeGraph` dominating CPU even on plain text rows; UIKit's scroll engine handles scrolling, each card body runs once per cell configuration.
- Cell reuse resets `@State` — every viewport re-entry re-runs `.onAppear` with a fresh state. For card-internal state (window picker, selected bar) either lift it into the TCA store, or seed it inside `withTransaction { $0.disablesAnimations = true }` on `.onAppear` so the seeding doesn't ride a phantom animation.
- `UIView.performWithoutAnimation { ... }` wraps `cell.host(...)` and `cv.reconfigureItems(...)` in `CycleStatsCardList`. Without it, UIKit applies an implicit animation block when `contentConfiguration` is set, which rides the size delta between `.estimated(220)` and the SwiftUI body's real height — that's the "card slides in from below on scroll" symptom.

## Animation

- Card-level motion goes through `withAnimation { ... }` imperatively in user-driven callbacks (taps, picker changes), **NOT** scoped `.animation(value:)` modifiers. Scoped animations override the host's `disablesAnimations` transaction and re-fire on cell reuse, so the bar/detail block re-springs every time the card scrolls back into view.
- `widgetCardStyle(interactive: false)` on cards with internal motion (`CycleTrendCard` chart + sliding detail block). Liquid Glass `.interactive()` runs a per-frame touch shader that competes with the chart's own animation while the finger is on the card.
- `.transition(...)` on insertion-only views (e.g. the trend detail block) is fine without a scoped animation — it only fires when the host's `withAnimation` provides the context, so cell reuse won't slide it in.

## Shell layout (Cycle Stats + Cycle Detail share the same shell)

- `ZStack { AppleHealthBackground().ignoresSafeArea(); content }`. The background extends edge-to-edge; the scroll surface stays in the safe area. `UICollectionView` (Cycle Stats) auto-pads its top by the nav-bar height via `contentInsetAdjustmentBehavior = .automatic`, so applying `.ignoresSafeArea(.container)` to the whole stack works there. SwiftUI's `ScrollView` (Cycle Detail) does **NOT** auto-adjust — same trick hides the first card under the translucent header. Pin `.ignoresSafeArea` to the background only when the scroll surface is a SwiftUI `ScrollView`.
- 28pt corner radius on every card on these two screens. 24pt is reserved for explainer-sheet sections (`CycleStatInfoSection`, `CycleStatInfoPersonalReading`).
- Toolbar leading: only the **root** Cycle Stats screen (`CycleInsightsView`) defines a custom chevron — it dismisses the whole insights flow, not just a stack pop. Pushed children (Cycle Details, history archive, stat info, customize) leave the toolbar leading slot empty so iOS uses the default native back chevron — adding a custom item there stacks two chevrons (custom + auto-generated native back).
- Title is Title Case ("Cycle Stats", "Cycle Details"), inline display mode. The headerEyebrow ("Averages & trends") is the secondary line, not the navigationTitle.

## Card vocabulary

- The `CycleTrendCard` is the heaviest card (chart + detail block). When `visiblePoints.count == 1` it swaps the variation/range/position metric row for `CycleTrendInviteBlock` — at one cycle, "On avg / 1/1" is mathematically tautological. The metric row earns its place at `count >= 2`.
- `TrendBarChart` lives in DesignSystem (`Components/Visualizations/`) and is "dumb": it owns no animation, no selection storage, just renders bars + axes. The host card owns selection + animation context. Y-axis labels are post-rounding deduplicated via `yAxisEntries` so a 27d–29d range doesn't render `28d` twice.
- `CycleNormality` is the single source of truth for cycle-length and period-length classification (in-range vs needs-attention). Both the trend chart's bar tint and the detail-screen badge call `CycleNormality.classifyCycleLength(days:)` so the two surfaces never disagree.

## State

- The feature reducer is `CycleInsightsFeature`. Stats / journey / insights / hidden-cycle keys / layout order all flow through its store. UI-only state (history navigation path, share-screen visibility) lives in `CycleInsightsView` `@State`.
- The data load effect floors the skeleton display at **400ms** whenever the screen enters with no cached aggregates (first appear, or post-`cycleDataChanged` invalidation). Local SwiftData fetches finish in <100ms; without the floor the skeleton flashes for a single frame and the numbers "pop in" without context — reads as a glitch, not as a load. The floor is **not** applied when stats are already cached (re-entry path) — that route doesn't show a skeleton at all, and a pause there would just feel slow.
- **`pendingInvalidation` flag, read by both view and `.onAppear`.** `HomeFeature` sets `state.cycleInsightsState.pendingInvalidation = true` (and the equivalent on `cycleJourneyState`) the instant `.calendar(.editPeriodPredictionsUpdated)` lands. Two consumers:
  1. **The view's `statsCardView` reads the flag directly** — `showStatsSkeleton = store.stats == nil || store.pendingInvalidation`. So the very first frame Cycle Stats renders post-edit reads as a skeleton, even before `.onAppear` runs. Without this, the previous-render value of `store.stats` (which still holds pre-edit numbers) flashes for a frame between the user landing on the screen and the reducer nulling it.
  2. `.onAppear` then consumes the flag — sets it to `false`, nulls aggregates, kicks the fetch with the 400ms skeleton floor. From there `store.stats == nil` keeps the skeleton on screen until fresh data arrives.
- Plain re-entry with no edits between visits leaves the flag `false`, so cached numbers stay on screen — back-from-detail and quick re-entries don't flash a skeleton on data that didn't change. **Don't** clear aggregates on `.dismissTapped` — that flashes a skeleton on every back.
- The canonical refresh path while the screen is *open* still flows through `cycleDataChanged`: Calendar waits 1s for SwiftData + predictions to settle, sends `delegate.periodDataChanged`, Today re-fetches, broadcasts `cycleDataUpdated`, HomeFeature fans out to `cycleInsights(.cycleDataChanged)` / `cycleJourney(.cycleDataChanged)`. These null aggregates and kick a fresh fetch — **except** when a refresh is already in flight (`state.isLoadingStats == true`). In that case `cycleDataChanged` only updates `cycleContext` and clears the invalidation flag, letting the in-flight fetch write the result when it returns. Without this guard, a user who enters the screen on `nil` state right before Calendar's broadcast lands would see two skeleton flashes back-to-back.
- **Don't add a separate eager-invalidate signal across features.** Earlier we tried `editLanded` + an `invalidateAggregates` action. It read fine in isolation but turned into a dual-signal protocol every consumer had to remember. The `pendingInvalidation` flag is the same effect achieved as plain state, set in one place and consumed in one place.
- `cardsReconfigureToken` is a stable hash of the data the cards depend on (loaded flags, hidden keys, layout order). It's the signal `CycleStatsCardList` uses to decide whether to call `reconfigureItems` (data refresh) vs nothing (pure scroll).
- `hiddenCycleKeys` is persisted in UserDefaults via the reducer (cycle-app users can hide individual cycles from the history surface without losing the underlying records).

## BodySignals card (`Cards/BodySignals/`)

HealthKit-backed "Your body" surface inside Cycle Stats. Conventions specific to this card:

### Permission flow

- The native HealthKit prompt is the single source of truth. **Don't** race custom screens against it.
- **Don't dismiss the presenting sheet synchronously when you fire `requestAuthorization()`.** Tearing down the presenter while iOS schedules the system dialog cancels the prompt — the sheet vanishes and nothing else happens.
- `BodySignalsAccessFlow` has two entry modes (`.prompt`, `.denied`) but **both land on Screen 1** — the explainer pitch ("how the link works", "your data, your call") is information the user wants regardless of their prior decision.
- Tap "Sync with Apple" routes synchronously on `permission`: granted/partial → dismiss; anything else → slide to Screen 2 (Settings instructions). We do not wait for the post-prompt re-load — waiting introduced a visible "tapped sync, nothing happened" pause on every iOS silent-skip path.
- The two screens **crossfade via paired opacity in a `ZStack`**, not slide via asymmetric transitions. The slide version left a one-frame empty backdrop mid-swap. `allowsHitTesting` routes taps to whichever side is visible. The animation lives on the parent `ZStack`; don't wrap the `showingManage` flip in an extra `withAnimation` block — it double-triggers the swap.
- iOS only shows the native sheet on the **first** call to `requestAuthorization()` per HealthKit type per app install. Subsequent calls return silently. `routeAfterSync` collapses every non-granted result (`.denied`, `.unavailable`, `.undetermined`) into Screen 2 — the user can't tell whether iOS skipped the prompt, they dismissed it, or refused, and Settings is the only forward path.

### Rendering states

`BodySignalsCard` picks among five exhaustive states (`RenderingState`):

1. `.loading` — only when there's no snapshot yet. Subsequent loads keep the prior snapshot on screen so the card doesn't flash a skeleton mid-cycle.
2. `.unavailable` — HealthKit can't see the device (e.g. iPad without Health).
3. `.needsPrompt` — auth is undetermined. CTA opens AccessFlow in `.prompt` mode.
4. `.noData` — auth was denied **or** all granted types returned empty samples. CTA opens AccessFlow in `.denied` mode.
5. `.data` — at least one snapshot value is present. **Wins over `.noData` whenever any snapshot value comes back** — partial permission renders as data with the missing types shown as "No data" rows, NOT as a global no-data state.

### `BodySignalsSnapshot.permission` ordering (in `HealthKitLocalClient.buildSnapshot()`)

1. Every read type still `.notDetermined` → `.undetermined`. **Don't collapse this into `.denied`** — Apple deliberately hides "user refused read access", so undetermined is the only honest signal that the system sheet hasn't been resolved.
2. All three returned with data → `.granted`.
3. Some types have data, others don't → `.partial`.
4. Past the prompt, all three fetches returned without error but **no metric has data** → `.partial`. Apple privacy reports `.sharingAuthorized` for read access regardless of the user's actual read decision, so we cannot distinguish "user denied read" from "user granted but has no Apple Watch samples yet" (no paired Watch, fresh install, no historical data). `.partial` keeps the card open with per-metric "No data" rows; routing to Settings would push out users who legitimately just don't have samples yet.
5. Every fetch errored → `.denied`. Real permission / unavailability problem; Settings is the right path.

### Settings hand-off

- `openSettings()` uses `app-settings:`, which lands on **cycle.app's** Settings page directly. The "Health" row sits there — one more tap and the user sees per-type toggles. iOS doesn't expose a public deep link to the per-type HealthKit page, so this is as close as we can land in two taps. Don't switch to `x-apple-health://` — that opens the Health app and forces 5+ taps through Profile → Privacy → Apps → cycle.app.
- Screen 2 instructions match the `app-settings:` path exactly: "Tap Health" → "Toggle each signal". Don't restore the older 4-step instructions — they describe a different path the URL doesn't take.

### Don't

- Don't bridge HealthKit through the legacy API client. `HealthKitLocalClient` is the only allowed boundary.
- Don't add a `BodySignalsAccessFlowMode` case without wiring its entry screen explicitly in `init` (the `_showingManage = State(initialValue:)` line). New modes that fall back to "Screen 1 by default" reintroduce the original race.

## Don't

- Don't add `.glassEffect(...)`, `.background(.ultraThinMaterial)`, or `.clipShape(...)` directly on a card body. `widgetCardStyle` owns the surface — stacking a second glass pass doubled per-frame GlassEntryView updates and was the dominant scroll cost on iOS 26.
- Don't drop `.equatable()` from the call site of `CycleTrendCard` / `CycleNormalityCard` / `CycleHistoryCard` in `CycleInsightsView.statsCardView(for:)`. SwiftUI uses it to short-circuit body re-evaluations on store mutations the card doesn't actually consume.
- Don't reach for `import UIKit` outside `CycleStatsCardList.swift` and `CycleTrendCard.swift`. The first hosts the collection view; the second routes `UISegmentedControl.appearance()` for the native picker tint. Anywhere else, stay in SwiftUI.

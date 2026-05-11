# BodyPatterns — Recurring symptom patterns surface

## What lives here

Destination screen pushed from Today's `symptomPatternSection` card. Surfaces recurring symptoms grouped by cycle phase — "Cramps in your menstrual phase, 4 of last 5 cycles". Sibling to `CycleInsights`, not nested.

Distinct from CycleInsights' BodySignals card (HealthKit metrics — wrist temp, HRV, resting HR). BodyPatterns aggregates `SymptomRecord` over `CycleRecord` lookback; BodySignals reads HealthKit live samples. Don't merge them.

## Folder layout

- `Models/` — `DetectedPattern.swift` (value type), `BodyPatternsPalette.swift` (phase ink mapping). Pure data + colour, no SwiftUI views, no TCA.
- `Components/` — sub-pieces of the screen: `SegmentedHalfArcGauge`, `BodyPatternsHeader`, `BodyPatternsSectionLabel`, `BodyPatternsFooterRows`, `BodyPatternsEmptyWidget`. Reusable across the screen + future detail pushes.
- `Cards/` — full widget cards. Currently `PatternWidgetCard` only — one detected pattern per card.
- `Screens/` — pushed children (How patterns work / When to see a doctor explainers, per-pattern detail). Empty for now; populate when Phase 2 + 3 land.
- Root: `BodyPatternsFeature.swift` (reducer), `BodyPatternsView.swift` (root view).

When adding a new file, name its role first. New widget kinds go in `Cards/`, sub-pieces in `Components/`, pushed children in `Screens/`. Don't drop a screen / explainer into `Cards/`.

## Phasing (this is a multi-pass build)

- **Phase 1 (shipped)**: mock data wiring. UI rendered end-to-end via `DetectedPattern.mockActive` + `.mockEmerging`. Replaced by Phase 2 below — kept as the empty-state fallback in `loadPatterns` until empty-state copy is finalized.
- **Phase 2 (shipped)**: `PatternDetector` in `Packages/Core/CycleEngine/PatternDetector.swift` — pure local algorithm over `CycleSnapshot` + `SymptomSnapshot` value types. Threshold: ≥3 matching cycles in same phase = confirmed; exactly 2 = emerging; <2 = dropped. Lookback: 12 months. SwiftData read happens in `MenstrualLocalClient+Patterns.swift` (`liveDetectPatterns`) inside `Task.detached`. Reducer's `loadPatterns` awaits `menstrualLocal.detectPatterns()`, maps `RawPatternSignal` → `DetectedPattern` via `BodyPatternsFeature.makePattern(from:)`, splits active/emerging, falls back to mock fixtures on empty result.
- **Phase 3 (pending)**: editorial body line (`pattern.editorial`) becomes OpenAI-generated. New `OpenAIClient` in `Packages/Core/Networking/` with a per-pattern prompt; cache the response per `(symptom, phase, cycleCount)` key in SwiftData. Never block render on the API — `BodyPatternsFeature.makeEditorial(...)` already returns a templated string; swap the call site for an OpenAI-cached lookup with the templated copy as fallback.

Phase 2 left two seams to track: (1) `liveDetectPatterns` falls back to mock fixtures when the detector returns empty — replace with proper empty-state copy when ready. (2) `neutralSymptoms` in `PatternDetector` is a small denylist (`all_good`, `calm`, `happy`, `energetic`, `focused`); add to it as new neutral symptoms are introduced rather than rebuilding the filter.

## Card visualization (water fill, May 2026)

The card itself IS the progress visualization — the half-arc speedometer was retired. `WaterFillBackdrop` (Components/) renders the card interior as a glass of water rising to `filled / total` of its height; `WaterShape` traces the meniscus with two superimposed sin waves so the surface ripples on a 30fps `TimelineView`. Phase ink colors the water; pale white sits above it.

- `PatternProgressBar` (Components/) is now a numeric headline only — big italic-free Bold count + "of N" caption + small caps "CYCLES" eyebrow. No segments, no orbs. The water level conveys the ratio.
- The water fill uses a low-opacity gradient (`color.opacity(0.18)` → `0.38`) so dark text on the card stays readable at any fill level. **Do not** raise these opacities without re-checking text contrast — phase inks are saturated and Black-on-Red is the regression we just fixed.
- Empty patterns (`total: 0`) → no card rendered. The empty-state widget (`BodyPatternsEmptyWidget`) handles the zero-data UX separately. The dashed `EmptyHalfArcGauge` was retired with the speedometer.

## Phase ink

- `BodyPatternsPalette.forPhase(_:)` is the only mapping site for phase → colour on this surface. Don't reach into `DesignColors.calendarPeriodGlyph` etc. directly inside views — go through the palette so we keep one place to update if we ever add a sixth phase / change the tokens.
- `accent` = saturated phase ink (filled gauge segments, eyebrow dot). `track` = phase ink at low opacity (empty gauge segments). `glow` = same hue at very low opacity (atmospheric radial behind the gauge). Three roles, three opacities; that's the whole vocabulary.

## Editorial copy

- `pattern.editorial` is one short paragraph (1–2 sentences, ≤140 chars). It's the slot for OpenAI hormonal copy in Phase 3.
- Voice: present tense, declarative, no diagnostic certainty. "Day 22 to 28. Persistent across this season's cycles." — not "You usually have bloating around Day 22." Match the Cycle Recap / Rhythm Reflection voice.
- Don't use em-dashes (`—`) in user-facing copy. The user-wide rule is en-dash (`–`) only. Codify in any prompt template before plugging into OpenAI.
- Phase 2 templates live in `BodyPatternsFeature.makeEditorial(...)`: emerging → "Day X to Y. One more cycle to confirm a pattern."; confirmed → "Day X to Y, recurring across N cycles." Phase 3 OpenAI swap should preserve these as fallbacks when the API call fails.

## Section labels (May 2026)

- The active / emerging carousels are labeled with `BodyPatternsSectionLabel` rendered as glass-pill capsules (`.ultraThinMaterial` + subtle terracotta stroke). Caller text is "Recurring patterns" (active) and "Just appearing" (emerging) — not "Active" / "Emerging". The original short labels were too cryptic per user feedback.
- Page dots between cards use a glass capsule with a wide active indicator (`Capsule` 18×6 for focused, 6×6 for inactive). The first card is auto-focused via `.onAppear { focusedID = first.id }` so the indicator never reads as "no card selected" on screen entry.

## Don't

- Don't render `PatternWidgetCard` outside this feature without a wrapper. The card is built around the `BodyPatternsPalette` and the gauge — exporting it raw to Today / CycleInsights couples those surfaces to this folder's choices.
- Don't add a chevron drill-in to the `BodyPatternsEmptyWidget`. Empty state has the Log Symptoms pill as its only affordance — adding a chevron implies there's somewhere to drill, which is a lie.
- Don't add a custom back button — the `NavigationStack` toolbar uses the native chevron tinted with `DesignColors.text`. Same as every other pushed screen; consistency is the point.
- Don't render the screen behind a `fullScreenCover`. It's an in-line ZStack overlay on `HomeView` (zIndex 4), same lifecycle pattern as Cycle Insights / Calendar. Cover would re-introduce the iOS modal inset and mismatch the rest of the navigation.

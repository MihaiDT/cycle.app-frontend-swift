# Daily Challenge Detail Screen Redesign

**Date:** 2026-04-13
**Branch:** `feature/local-first-migration`
**Supersedes:** UI portion of `2026-04-13-daily-glow-phase1-design.md` for `ChallengeAcceptView` only

## Why

The current `ChallengeAcceptView` — shown as a `.medium` detent sheet after the user taps the Daily Glow challenge card — was rejected in a design review. Specific issues:

- Plain text-only layout with no visual hierarchy
- Displays **"Luteal Day 0"** (a bug — `cycleDay` is hardcoded to 0 upstream)
- A 5-dot rating for `energyLevel` has no legend; users can't tell what it means
- A 🥇 medal emoji for the `goldHint` feels gamey and off-brand for a women's wellness app
- `.medium` detent cuts off content; CTA and tips require cramped scrolling
- "50–100 XP" is presented as a dominant reward, not a quiet consequence

The feel we're targeting is "Tolan × Apple Fitness workout detail": typography-led, clearly-boxed content, nothing decorative for its own sake, every element answering a user question.

## Goals

1. Premium, Apple-style full-screen presentation
2. Typography-led hierarchy where scale alone carries emphasis
3. Every element answers a question the user is asking ("what is this / why should I / can I now / how do I / how do I start / what do I get")
4. Uses existing `DesignColors` palette — no new palette tokens except one card surface color
5. Preserves all existing functionality (camera, gallery, cancel)

## Non-goals

- Not changing the `ChallengeSnapshot` model or persisted fields
- Not changing the `ChallengeAcceptFeature` reducer / actions / delegate
- Not touching `PhotoReviewFeature`, `ValidationFeature`, or `ValidationResultView`
- Not fixing the upstream `cycleDay == 0` bug (the redesign avoids displaying `cycleDay` at all, which makes the fix lower priority for this work)
- Not adding a backend field for a separate "why this challenge" line (existing `challengeDescription` is reused as the subtitle)
- Not internationalizing new strings (matches existing codebase pattern — no `.strings` files in use today)

## Target design (v3, approved)

Wireframe mockup lives in `.superpowers/brainstorm/71952-1776095485/content/tolan-direction-v3.html` (checked into `.superpowers/` which is gitignored but co-located for reference).

### Container

- `.fullScreenCover(item:)` in `TodayFeature.swift:1136-1147` (was `.sheet(item:)`)
- Remove `.presentationDetents`, `.presentationDragIndicator`, `.presentationCornerRadius`, `.presentationBackground` modifiers — none apply to `fullScreenCover`
- No `NavigationStack`; the dismiss `✕` is inline at top-trailing of the scroll content
- Root background: `DesignColors.background`
- TCA `store.scope(state:action:)` wiring stays byte-identical

### Screen anatomy (top → bottom)

```
┌────────────────────────────────────┐
│                             [ ✕ ]  │  top bar — trailing X
│                                    │
│  TODAY · LUTEAL PHASE              │  phase anchor (tiny terracotta)
│                                    │
│  Smile at                          │
│  three                             │  44pt title, Raleway-Black,
│  people.                           │  3-line break, left-aligned
│                                    │
│  Make genuine eye contact and      │
│  smile at three different people…  │  17pt subtitle (why)
│                                    │
│  ┌──────┐  ┌──────┐  ┌──────┐      │
│  │5 min │  │Gentle│  │Social│      │  stat row — 3 text-only
│  │ TIME │  │EFFORT│  │ THEME│      │  boxes, no icons
│  └──────┘  └──────┘  └──────┘      │
│                                    │
│  ┌────────────────────────────┐    │
│  │ HOW TO DO IT               │    │
│  │                            │    │  how card — warm cream,
│  │ (1) A real smile reaches…  │    │  numbered cocoa circles
│  │ (2) Try it with a cashier…│    │
│  │ (3) Notice how it feels…   │    │
│  └────────────────────────────┘    │
│                                    │
│      …scrolls under CTA…           │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ Start challenge            →  │ │  pinned CTA — cocoa with
│ └────────────────────────────────┘ │  cream arrow badge
│       Or choose from gallery       │  secondary text button
│   Earns 50–100 glow on completion  │  quiet reward footer
└────────────────────────────────────┘
```

### Typography

Raleway-Black, Raleway-SemiBold, Raleway-Medium, and Raleway-Regular are all bundled and registered in `CycleApp/Resources/Info.plist`. No new font additions needed.

| Element        | Font weight     | Size | Color           | Notes                                                                 |
|----------------|-----------------|------|-----------------|-----------------------------------------------------------------------|
| Phase anchor   | Raleway-Bold    | 11   | `accentWarm`    | `.textCase(.uppercase)`, kerning 0.12em                               |
| Title          | Raleway-Black   | 44   | `text`          | `lineSpacing(-6)` for tight 0.92 leading, kerning -0.02em            |
| Why subtitle   | Raleway-Medium  | 17   | `textPrincipal` | 2-3 lines, natural line height                                        |
| Stat value     | Raleway-Black   | 20   | `text`          | Shrinks to 16 if value string is wider than box                       |
| Stat label     | Raleway-Bold    | 9    | `textSecondary` | Uppercase, kerning 0.1em                                              |
| Card header    | Raleway-Black   | 10   | `accentWarm`    | Uppercase, kerning 0.12em                                             |
| Tip body       | Raleway-Medium  | 15   | `textPrincipal` | Line height 1.42                                                      |
| CTA label      | Raleway-Black   | 17   | `background`    | Kerning -0.01em                                                       |
| Gallery button | Raleway-SemiBold| 13   | `textSecondary` | Plain text button                                                     |
| Reward footer  | Raleway-SemiBold| 11   | `textSecondary` | Centered                                                              |

### Layout & spacing

- Horizontal padding on title / subtitle / phase anchor: 22pt
- Stat row horizontal outer: 20pt; 3-column grid with 10pt column gap
- Stat box: 20pt corner radius, 18pt vertical padding, 10pt horizontal padding, 1pt border at `text.opacity(0.07)`, card background `cardWarm`
- How card: 20pt outer horizontal, 24pt corner radius, 22pt inner horizontal, 18pt inner vertical, 1pt border at `text.opacity(0.07)`, background `cardWarm`
- Tip item: 12pt vertical padding each, 14pt gap between number circle and text, 1pt `text.opacity(0.08)` divider between tips
- CTA area: pinned to bottom safe area + 18pt; 30pt corner radius, 20pt vertical + 26pt horizontal padding, drop shadow `text.opacity(0.22)` y:8 blur:20, inner arrow badge 32×32 circle
- Gallery button: 12pt top padding from CTA
- Reward footer: 4pt top padding from gallery button
- Scroll content bottom spacer: 170pt to guarantee no overlap with the pinned CTA cluster
- CTA fade gradient: `background` at 100% transitioning to transparent over the top 28pt of the CTA container, so scroll content dissolves under the button cleanly

### Colors (from `DesignColors`)

| Token             | Hex       | Usage                              |
|-------------------|-----------|------------------------------------|
| `background`      | `#FDFCF7` | Screen background, CTA arrow fill  |
| `text`            | `#5C4A3B` | Title, stat values, CTA background |
| `textPrincipal`   | `#7A5F50` | Subtitle, card body                |
| `textSecondary`   | `#6E6A68` | Stat labels, reward footer         |
| `accentWarm`      | `#C18F7D` | Phase anchor, card header          |
| `cardWarm` **new**| `#F7F2E8` | Stat box & how card surface        |

**New token:** `DesignColors.cardWarm = Color(hex: 0xF7F2E8)` — added in `Packages/Core/DesignSystem/DesignColors.swift`, in the "Backgrounds" section alongside `background` and `backgroundElegant`.

### Stat row derivations

All three values are computed locally from existing `ChallengeSnapshot` fields — no data model or backend changes.

```swift
extension ChallengeSnapshot {
    /// Short label for the stat row. `energyLevel` is a 1–10 scale.
    var effortDisplay: String {
        switch energyLevel {
        case ...3:  return "Gentle"
        case 4...6: return "Moderate"
        default:    return "Active"   // 7–10
        }
    }

    /// Human-readable category label for the stat row.
    var themeDisplay: String {
        switch challengeCategory.lowercased() {
        case "self_care":   return "Self care"
        case "mindfulness": return "Mindful"
        case "movement":    return "Movement"
        case "creative":    return "Creative"
        case "nutrition":   return "Nutrition"
        case "social":      return "Social"
        default:            return challengeCategory.capitalized
        }
    }

    /// Time estimate for the stat row. Local heuristic — no backend field today.
    var durationDisplay: String {
        switch challengeCategory.lowercased() {
        case "creative":                         return "15 min"
        case "movement":                         return "10 min"
        default:                                 return "5 min"  // social, mindfulness, self_care, nutrition
        }
    }
}
```

Extension lives at the bottom of `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift`, not in `Packages/Core/Persistence/ChallengeSnapshot.swift` — the flat compilation model allows this, and it keeps display-layer concerns co-located with the view that uses them.

### Phase anchor

- String: `"Today · \(cyclePhase.capitalized) phase"` → rendered uppercase by `.textCase(.uppercase)`
- Never displays `cycleDay` — sidesteps the "Day 0" bug entirely

### Why subtitle

Reuses `challenge.challengeDescription` unchanged. The existing descriptions already blend "what" and "why" framing (e.g. *"Make genuine eye contact and smile at three different people today. Small moments of human warmth ripple outward."*) and sit naturally as a subtitle under the title.

### How card

- Renders `challenge.tips` as an ordered list
- Each number is a 24×24 filled `text` circle with `background` digit in Raleway-Black 11pt
- Supports any count of tips; the divider pattern is `1pt text.opacity(0.08)` between siblings, no divider above the first or below the last

### CTA behavior

- **Primary** — "Start challenge" — tap → `store.send(.openCameraTapped)` (existing action)
- **Secondary** — "Or choose from gallery" — tap → `store.send(.chooseFromGalleryTapped)` (existing action)
- **Footer** — "Earns 50–100 glow on completion" — non-interactive

The `"50–100 XP"` wording is replaced with `"50–100 glow"` — matches the Daily Glow feature naming. The range is hardcoded here (same as today); future iteration can tie it to the validation rating scale.

## Implementation plan

### Files to change

**1. `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift`** (currently 151 lines)

- Reducer (`@Reducer` block, lines 6-38): **no change**
- `ChallengeAcceptView` body: **full rewrite** to the v3 layout
- New private subviews at file scope: `PhaseAnchor`, `TitleBlock`, `StatBox`, `StatRow`, `HowCard`, `TipRow`, `CTAStack`
- New `ChallengeSnapshot` display extension at the bottom of the file (see above)
- Estimated final size: 380–420 lines
- If it crosses 500 lines, split out `ChallengeAcceptComponents.swift` per the file-splitting rule in `feedback_file_splitting`

**2. `Packages/Features/Home/TodayFeature.swift`** (lines 1136–1147)

- Change `.sheet(item:)` → `.fullScreenCover(item:)`
- Delete 4 presentation modifiers: `.presentationDetents`, `.presentationDragIndicator`, `.presentationCornerRadius`, `.presentationBackground`
- Keep the `$store.scope(state: action:)` block unchanged
- No other lines in `TodayFeature.swift` touched

**3. `Packages/Core/DesignSystem/DesignColors.swift`**

- Add `public static let cardWarm = Color(hex: 0xF7F2E8)` to the "Backgrounds" section

### No changes needed

- `ChallengeAcceptFeature` reducer / actions / delegate
- `ChallengeSnapshot` model, `ChallengeRecord` SwiftData model
- `DailyChallengeFeature` (parent reducer)
- `PhotoReviewFeature`, `ValidationFeature`, `ValidationResultView`
- `challenge_templates.json`
- Backend (`dth-backend`)
- `project.yml` / `xcodegen generate` (no file adds unless the 500-line split happens)

### Manual QA

On the iPhone 16 simulator, after `./scripts/dev.sh`:

1. Navigate Home → tap today's Daily Glow card
2. `.fullScreenCover` appears (not a sheet with a grabber)
3. Top-right `✕` dismisses cleanly back to Home
4. Title renders correctly for:
   - Short (2-word) titles, e.g. *"Deep rest"*
   - Long (6+ word) titles, e.g. *"Plan a future adventure with friends"*
5. Stat row renders correctly for:
   - `energyLevel = 2` → "Gentle"
   - `energyLevel = 5` → "Moderate"
   - `energyLevel = 9` → "Active"
6. Stat row themes render correctly across all 6 categories (`social`, `mindfulness`, `movement`, `nutrition`, `self_care`, `creative`)
7. "Start challenge" → camera opens (`PhotoCaptureView` via existing flow)
8. "Or choose from gallery" → photo picker opens
9. Scroll content never hides behind the pinned CTA cluster
10. Dynamic Type at XL: title may shrink or wrap more; stat row labels stay readable

### Accessibility

- Phase anchor: `.accessibilityLabel("Today, \(cyclePhase) phase")`
- Title: `.accessibilityLabel(challengeTitle).accessibilityAddTraits(.isHeader)`
- Stat row: grouped as one element with label `"Takes \(durationDisplay), effort level \(effortDisplay), theme \(themeDisplay)"`
- Each tip: `.accessibilityLabel("Step \(n): \(tip)")`
- CTA: `.accessibilityLabel("Start challenge").accessibilityHint("Opens the camera to take a photo of your challenge")`
- Gallery button: `.accessibilityHint("Choose an existing photo instead of taking a new one")`
- Reward footer: `.accessibilityLabel("Earns 50 to 100 glow points on completion")`

### Scope boundary

Anything not listed above is out of scope for this spec. Specifically:
- Fixing the `cycleDay == 0` upstream bug
- Redesigning `ValidationResultView` (the *after-validation* screen)
- Adding streaks, level badges, or completion history to this screen
- Backend changes for a dedicated `whyLine` or `estimatedMinutes` field

## Decisions (locked)

1. **`cardWarm` = `#F7F2E8`.** Explicit token, not an opacity blend. Matches the pattern of existing `background`/`backgroundElegant` and stays visually stable regardless of compositing context.
2. **Duration heuristic is local for v1.** Shipping correctness today beats shipping perfection in two weeks. Upgrade path: replace `durationDisplay` with `challenge.estimatedMinutes` when backend adds the field. Filed as a follow-up, not a blocker.
3. **Gallery is a plain-text button directly below the primary CTA.** Discoverable at a glance, doesn't clutter the CTA, and matches iOS photo-flow patterns. Long-press and icon-adjacent alternatives were considered and rejected (discoverability / visual balance).
4. **"glow" in user-facing copy.** Feature is called Daily Glow, the profile model is `GlowProfileSnapshot`, "XP" is generic gaming language that doesn't fit a women's wellness tone. Code field names (`xpEarned`, `XPProgressBar`, etc.) stay as-is — renaming them is out of scope for this spec.

## Follow-ups (deferred, not blocking)

- Backend `estimatedMinutes` field on challenge generation prompt + `ChallengeSnapshot` — replaces the local heuristic.
- Backend `whyLine` field for a dedicated subtitle string (currently reusing `challengeDescription`).
- Fix for the upstream `cycleDay == 0` bug — this redesign sidesteps it by not displaying `cycleDay`, but the bug is still live for any other consumer.
- Rename `xpEarned` → `glowEarned` across the codebase (cosmetic consistency pass).

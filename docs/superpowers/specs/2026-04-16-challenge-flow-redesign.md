# Challenge Flow Redesign

**Date:** 2026-04-16
**Status:** Approved for implementation

## Problem

The challenge flow is fragmented — user taps "I'm in", gets bounced between separate modal sheets (accept → camera → photo review → validation), returning to Home between each step. This breaks the "daily ritual" feel and kills completion rates.

## Solution

Replace the fragmented modal flow with a **single full-screen continuous journey** from timer to celebration. User never sees Home until they finish or explicitly exit.

## Flow

```
Home card "I'm in" (exists)
    ↓
Accept sheet — challenge details + tips (exists)
    ↓
"Start challenge"
    ↓
┌─────────────────────────────────────┐
│  FULL-SCREEN CHALLENGE JOURNEY      │
│                                     │
│  Step 1: Timer + Tips (read-only)   │
│     ↓                               │
│  Step 2: Camera + Photo Review      │
│     ↓                               │
│  Step 3: Aria Validates             │
│     ↓                               │
│  Step 4: Celebration                │
│     ↓                               │
│  "Back to my day" → Home            │
└─────────────────────────────────────┘
```

## Screens

### Screen 1: Challenge In Progress (NEW)

- Progress dots (1 of 3 active)
- Close button (X) top-left, challenge title top-center
- Timer ring: countdown based on category duration (5/10/15 min)
- Aurora card with "How to" tips — read-only numbered list (1, 2, 3, 4), no checkboxes
- "I'm done" primary CTA
- Hint: "Timer continues in Dynamic Island"
- **Live Activity starts** when this screen appears

**Timer durations by category:**
- Mindfulness, Self-care, Social: 5 min
- Movement: 10 min
- Creative, Nutrition: 15 min

### Screen 2: Proof Photo (REFACTORED)

- Progress dots (2 of 3)
- Back arrow + "Show Aria" title
- Camera viewfinder with rule-of-thirds grid
- Personalized prompt bubble per challenge (e.g. "Show your stretch setup")
- Shutter button (terracotta accent)
- Gallery / Retake actions
- After photo taken: inline preview with Submit / Retake (no separate PhotoReview modal)
- **Live Activity ends** when photo is submitted

### Screen 3: Aria Validates (REFACTORED)

- Progress dots (3 of 3)
- Centered pulsing circle (terracotta dot with blush glow) — no emoji, no sparkles
- "Aria is checking..." title
- "Matching your photo with the challenge" subtitle
- 2-3 second loading while API validates

### Screen 4: Celebration (REFACTORED)

- All progress dots done
- Aurora celebration card:
  - "Beautiful!" (or AI-generated one-liner)
  - AI feedback text about the activity + cycle phase
  - "Challenge complete" badge (terracotta pill)
  - Gamification progress (placeholder — will be redesigned in dedicated session)
  - Streak display
- "Back to my day" primary CTA
- "New challenge tomorrow" hint

### Live Activity (NEW)

**Dynamic Island — Compact:**
- Breathing glow dot (terracotta, pulsating) + countdown timer

**Dynamic Island — Expanded:**
- Challenge title + cycle phase
- Large countdown timer
- Time progress bar (terracotta gradient)
- "I'm done" CTA button

**Lock Screen:**
- "cycle" brand name
- Challenge title
- Large countdown timer + "remaining" label
- Time progress bar

## Architecture

### New Files

```
Packages/Features/Home/Glow/
├── ChallengeJourneyFeature.swift    # TCA reducer — state machine for the 4 steps
├── ChallengeJourneyView.swift       # Main full-screen view, switches on step
├── ChallengeTimerView.swift         # Step 1: timer + tips
├── ChallengeProofView.swift         # Step 2: camera + photo review (inline)
├── ChallengeValidationView.swift    # Step 3: Aria checking animation
├── ChallengeCelebrationView.swift   # Step 4: celebration card
├── ChallengeTimerManager.swift      # Timer logic + Live Activity bridge
└── ChallengeActivityAttributes.swift # ActivityKit Live Activity definition

Packages/Features/Home/Glow/ChallengeJourney/
└── (widget target files for Live Activity)
```

### State Machine

```swift
enum ChallengeJourneyStep: Equatable, Sendable {
    case timer           // Step 1: doing the challenge
    case proof           // Step 2: camera + review
    case validating      // Step 3: Aria checks
    case celebration     // Step 4: done!
}
```

### Integration

- `DailyChallengeFeature` presents `ChallengeJourneyFeature` as a single `fullScreenCover` instead of separate accept → camera → photoReview → validation sheets
- `ChallengeAcceptFeature` delegates `.startChallenge` → opens `ChallengeJourneyFeature`
- `ChallengeJourneyFeature` handles the entire flow internally, only delegates back `.completed` or `.cancelled` to parent

### What Gets Removed

- `PhotoReviewFeature` as a separate presented feature (merged into proof step)
- `ValidationFeature` as a separate presented sheet (merged into journey)
- `isShowingCamera` / `isShowingGallery` booleans on DailyChallengeFeature (camera is part of journey)
- Separate fullScreenCover/sheet presentations for each step

### What Stays

- `DailyChallengeCardView` — home card with "I'm in"
- `ChallengeAcceptFeature` — accept sheet with details + "Start challenge"
- `ChallengeSnapshot` model — unchanged
- `GlowLocalClient` — persistence unchanged
- API validation endpoint — unchanged

## Design Tokens

All colors from DesignColors:
- Background: `#FDFCF7` (bg)
- Card surface: `#F2EBDC` → `#E6D4C4` (aurora gradient)
- Text: `#5C4A3B` (cocoa), `#7A5F50` (principal), `#A69F98` (placeholder)
- Accent: `#C18F7D` (terracotta warm — CTAs, timer ring, shutter)
- Secondary: `#D6A59A` (dusty rose — gradient ends)
- Soft: `#EBCFC3` (blush — backgrounds, glows)
- Structure: `#DECBC1` (borders, dividers)

Font: Raleway throughout. No emoji icons. No sparkle effects.

## Gamification

Placeholder for now — "Challenge complete" badge, progress bar (X of Y), streak count. Full gamification system to be designed in a separate session. The celebration view must be easy to swap out.

## Out of Scope

- Gamification redesign (separate session)
- Challenge template changes
- Backend API changes
- Notification scheduling changes

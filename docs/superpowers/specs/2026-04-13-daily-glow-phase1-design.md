# Daily Glow — Phase 1: Core Loop Design Spec

## Overview

Transform the Do card in CardStackFeature into a daily photo challenge system. Users see a cycle-phase-personalized challenge, take a photo, get AI validation from Aria, earn XP, and level up. This spec covers Phase 1 (core loop only) — Diary, Profile, Share, and Intelligence come in later phases.

## Scope — What Ships in Phase 1

- SwiftData models + snapshots + GlowLocalClient
- 80 challenge templates JSON + selector engine
- Do card upgrade (3 states: available / completed / skipped)
- Challenge accept sheet (S2)
- System camera + gallery via UIImagePickerController/PHPicker (no custom AVCaptureSession)
- Photo review screen (S4)
- Validation result screen (S5) with rating animations
- Backend endpoint wiring (POST /api/challenge/validate)
- XP + level calculation
- Level up overlay (S9)

## What Does NOT Ship in Phase 1

- Custom camera with glass overlay (S3) — system camera is sufficient
- Glow Diary (S6), Photo Detail (S7), Glow Profile (S8) — Phase 2
- Share Card (S10) — Phase 3
- Engagement decay, premium gates, intelligence — Phase 3
- GlowStreakBanner, GlowMeSection — Phase 2

---

## Data Layer

### SwiftData Models

Both files live flat in `Packages/Core/Persistence/` (matching existing pattern — no subdirectories).

#### ChallengeRecord

```swift
@Model
final class ChallengeRecord {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var date: Date = .now
    @Attribute(.allowsCloudEncryption) var templateId: String = ""
    @Attribute(.allowsCloudEncryption) var challengeCategory: String = ""
    @Attribute(.allowsCloudEncryption) var challengeTitle: String = ""
    @Attribute(.allowsCloudEncryption) var challengeDescription: String = ""
    @Attribute(.allowsCloudEncryption) var tips: String = "[]"
    @Attribute(.allowsCloudEncryption) var goldHint: String = ""
    @Attribute(.allowsCloudEncryption) var validationPrompt: String = ""
    @Attribute(.allowsCloudEncryption) var cyclePhase: String = ""
    @Attribute(.allowsCloudEncryption) var cycleDay: Int = 0
    @Attribute(.allowsCloudEncryption) var energyLevel: Int = 3
    @Attribute(.allowsCloudEncryption) var status: String = "available"  // available | completed | skipped
    @Attribute(.allowsCloudEncryption) var completedAt: Date?
    @Attribute(.allowsCloudEncryption) var photoData: Data?
    @Attribute(.allowsCloudEncryption) var photoThumbnail: Data?
    @Attribute(.allowsCloudEncryption) var validationRating: String?     // bronze | silver | gold
    @Attribute(.allowsCloudEncryption) var validationFeedback: String?
    @Attribute(.allowsCloudEncryption) var xpEarned: Int = 0
}
```

Changes from original spec:
- Added `templateId` — stores the template's unique `id` so `ChallengeSelector` can exclude recently completed templates (not just categories)
- Renamed `challengeType` → `challengeCategory` — clarifies this is the category (social, self_care, etc.)
- Added `validationPrompt` — needed at photo submit time, stored with the challenge
- Replaced `isCompleted: Bool` + `isSkipped: Bool` → single `status: String` — eliminates invalid state where both could be true

#### GlowProfileRecord

```swift
@Model
final class GlowProfileRecord {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var totalXP: Int = 0
    @Attribute(.allowsCloudEncryption) var currentLevel: Int = 1
    @Attribute(.allowsCloudEncryption) var totalCompleted: Int = 0
    @Attribute(.allowsCloudEncryption) var currentConsistencyDays: Int = 0
    @Attribute(.allowsCloudEncryption) var longestConsistencyDays: Int = 0
    @Attribute(.allowsCloudEncryption) var lastCompletedDate: Date?
    @Attribute(.allowsCloudEncryption) var goldCount: Int = 0
    @Attribute(.allowsCloudEncryption) var silverCount: Int = 0
    @Attribute(.allowsCloudEncryption) var bronzeCount: Int = 0
}
```

#### CycleDataStore Registration

Add both models to the schema array in `CycleDataStore.swift`:

```swift
public static let schema = Schema([
    // ... existing 11 models ...
    ChallengeRecord.self,
    GlowProfileRecord.self,
])
```

This MUST happen before any `ModelContext` for these types is created, or SwiftData will crash.

### Snapshots (Immutable Value Types for TCA)

Files live flat in `Packages/Core/Persistence/` (no Snapshots/ subdirectory).

```swift
struct ChallengeSnapshot: Equatable, Sendable {
    let id: UUID
    let date: Date
    let templateId: String
    let challengeCategory: String
    let challengeTitle: String
    let challengeDescription: String
    let tips: [String]
    let goldHint: String
    let validationPrompt: String
    let cyclePhase: String
    let cycleDay: Int
    let energyLevel: Int
    var status: ChallengeStatus
    var completedAt: Date?
    var photoThumbnail: Data?
    var validationRating: String?
    var validationFeedback: String?
    var xpEarned: Int

    enum ChallengeStatus: String, Equatable, Sendable {
        case available
        case completed
        case skipped
    }
}

struct GlowProfileSnapshot: Equatable, Sendable {
    let id: UUID
    var totalXP: Int
    var currentLevel: Int
    var totalCompleted: Int
    var currentConsistencyDays: Int
    var longestConsistencyDays: Int
    var lastCompletedDate: Date?
    var goldCount: Int
    var silverCount: Int
    var bronzeCount: Int

    var levelTitle: String {
        GlowConstants.levelFor(xp: totalXP).title
    }

    var isMaxLevel: Bool {
        currentLevel >= GlowConstants.levels.last!.level
    }
}
```

Changes from original spec:
- Removed `Codable` from `ChallengeSnapshot` — avoids unintentional base64 serialization of `photoThumbnail: Data?` in TCA state debug/crash recovery
- Replaced dual booleans with `ChallengeStatus` enum — single source of truth, impossible invalid state
- Added `templateId`, `validationPrompt`, `challengeCategory` to match updated `ChallengeRecord`
- Added `isMaxLevel` computed property to `GlowProfileSnapshot`
- `levelTitle` now delegates to `GlowConstants` instead of inline switch

### GlowLocalClient

Lives flat in `Packages/Core/Persistence/` (matching `MenstrualLocalClient` pattern).

```swift
public struct GlowLocalClient: Sendable {
    public var getTodayChallenge: @Sendable () async throws -> ChallengeSnapshot?
    public var saveChallenge: @Sendable (ChallengeSnapshot) async throws -> Void
    public var completeChallenge: @Sendable (UUID, Data, Data, String, String, Int) async throws -> Void
    public var skipChallenge: @Sendable (UUID) async throws -> Void
    public var getProfile: @Sendable () async throws -> GlowProfileSnapshot
    /// Returns (previousProfile, updatedProfile). The `rating` param ("bronze"/"silver"/"gold") updates rating counts.
    public var addXP: @Sendable (_ amount: Int, _ rating: String) async throws -> (previous: GlowProfileSnapshot, current: GlowProfileSnapshot)
    public var getRecentCompletedTemplateIds: @Sendable (_ days: Int) async throws -> [String]
}

extension GlowLocalClient: DependencyKey {
    public static let liveValue = GlowLocalClient.live()
    public static let testValue = GlowLocalClient.mock()
    public static let previewValue = GlowLocalClient.mock()
}

extension DependencyValues {
    public var glowLocal: GlowLocalClient {
        get { self[GlowLocalClient.self] }
        set { self[GlowLocalClient.self] = newValue }
    }
}
```

Changes from original spec:
- Added `public` modifiers throughout — matches `MenstrualLocalClient` pattern
- Renamed `getRecentCompletedTypes` → `getRecentCompletedTemplateIds` — returns template IDs (not categories) for selector exclusion
- Documented the `rating` parameter on `addXP` — it updates `goldCount`/`silverCount`/`bronzeCount`
- Full `DependencyKey` + `DependencyValues` extension shown

---

## Challenge Engine

Files live in `Packages/Core/CycleEngine/` (alongside `HBICalculator.swift`, `MenstrualPredictor.swift`).

### ChallengeTemplate

```swift
struct ChallengeTemplate: Codable, Sendable {
    let id: String
    let category: String          // social, self_care, creative, movement, mindfulness, nutrition
    let phases: [String]          // ["ovulatory", "follicular"]
    let energyMin: Int
    let energyMax: Int
    let title: String
    let description: String
    let tips: [String]
    let goldHint: String
    let validationPrompt: String  // sent to AI at photo submit
}
```

### ChallengeTemplatePool

Loads `challenge_templates.json` from bundle at first access. Caches in memory.

```swift
struct ChallengeTemplatePool: Sendable {
    static let shared = ChallengeTemplatePool()
    let templates: [ChallengeTemplate]
}
```

### ChallengeSelector

Stateless. Pure function:

```swift
enum ChallengeSelector {
    static func select(
        phase: String,
        energyLevel: Int,
        recentTemplateIds: [String],
        templates: [ChallengeTemplate]
    ) -> ChallengeTemplate?
}
```

Algorithm:
1. Filter templates where `phases` contains current phase
2. Filter where `energyMin <= energyLevel <= energyMax`
3. Exclude templates whose `id` is in `recentTemplateIds` (completed last 14 days)
4. If empty after step 3, relax: only apply phase filter + exclude recent
5. If still empty, return any non-recent template
6. Random weighted pick from remaining

---

## Feature Architecture

### Integration Point: TodayFeature

TodayFeature gains a new child feature:

```swift
// TodayFeature.State additions:
var dailyChallengeState: DailyChallengeFeature.State = .init()

// TodayFeature.Action additions:
case dailyChallenge(DailyChallengeFeature.Action)

// TodayFeature.body additions:
Scope(state: \.dailyChallengeState, action: \.dailyChallenge) {
    DailyChallengeFeature()
}
```

TodayFeature coordinates between CardStackFeature and DailyChallengeFeature:
- On `phaseResolved(phase, day, energy)` → sends `.dailyChallenge(.selectChallenge(phase:energyLevel:))`
- On `.cardStack(.delegate(.challengeDoItTapped))` → sends `.dailyChallenge(.doItTapped)`
- On `.cardStack(.delegate(.challengeSkipTapped))` → sends `.dailyChallenge(.skipTapped)`
- On `.dailyChallenge(.delegate(.challengeStateChanged(snapshot)))` → updates `cardStackState.challengeSnapshot`

### CardStackFeature Changes

Minimal additions to `CardStackFeature`:

**State:**
```swift
var challengeSnapshot: ChallengeSnapshot?  // passed from parent via delegate
```

**Action — new delegate cases:**
```swift
enum Delegate: Sendable {
    // ... existing cases ...
    case challengeDoItTapped
    case challengeSkipTapped
    case challengeMaybeLaterTapped
}
```

**Reducer — connect existing `actionTapped` to new delegates:**

The existing `actionTapped(DailyCard)` handler has `.challenge` returning `.none`. Change this to:

```swift
case let .actionTapped(card) where card.cardType == .do:
    // When a challenge is active, route to challenge delegates
    if state.challengeSnapshot != nil {
        return .none // handled by DailyChallengeCardView buttons directly via delegate
    }
    // ... existing do card handling
```

The "Do It" and "Skip" buttons in `DailyChallengeCardView` send actions that CardStackFeature maps to delegate actions. This keeps CardStackFeature's reducer thin — it just passes through.

**View — DailyChallengeCardView replaces Do card body:**

In `CardStackView`, when rendering a `.do` type card:
```swift
if let challenge = store.challengeSnapshot {
    DailyChallengeCardView(challenge: challenge, onDoIt: { ... }, onSkip: { ... })
} else {
    // existing Do card rendering
}
```

### DailyChallengeFeature (Coordinator Reducer)

Lives in `Packages/Features/Home/Glow/DailyChallengeFeature.swift`.

```swift
@Reducer
struct DailyChallengeFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        var challenge: ChallengeSnapshot?
        var profile: GlowProfileSnapshot?
        var challengeState: ChallengeState = .idle

        enum ChallengeState: Equatable, Sendable {
            case idle
            case available
            case skipped
            case completed
        }

        // Sheet/cover presentations
        @Presents var acceptSheet: ChallengeAcceptFeature.State?
        @Presents var photoCapture: PhotoCaptureState?
        @Presents var photoReview: PhotoReviewFeature.State?
        @Presents var validation: ValidationFeature.State?
        @Presents var levelUp: LevelUpFeature.State?
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)

        case selectChallenge(phase: String, energyLevel: Int)
        case challengeSelected(ChallengeSnapshot)
        case doItTapped
        case skipTapped
        case maybeLaterTapped

        case acceptSheet(PresentationAction<ChallengeAcceptFeature.Action>)
        case photoCapture(PresentationAction<PhotoCaptureAction>)
        case photoReview(PresentationAction<PhotoReviewFeature.Action>)
        case validation(PresentationAction<ValidationFeature.Action>)
        case levelUp(PresentationAction<LevelUpFeature.Action>)

        case photoCaptured(Data)
        case validationCompleted(ChallengeSnapshot, GlowProfileSnapshot, GlowProfileSnapshot)

        case delegate(Delegate)
        enum Delegate: Sendable {
            case challengeStateChanged(ChallengeSnapshot?)
        }
    }

    @Dependency(\.glowLocal) var glowLocal
    @Dependency(\.anonymousID) var anonymousID
    @Dependency(\.apiClient) var apiClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in ... }
            .ifLet(\.$acceptSheet, action: \.acceptSheet) { ChallengeAcceptFeature() }
            .ifLet(\.$photoReview, action: \.photoReview) { PhotoReviewFeature() }
            .ifLet(\.$validation, action: \.validation) { ValidationFeature() }
            .ifLet(\.$levelUp, action: \.levelUp) { LevelUpFeature() }
    }
}
```

Changes from original spec:
- Added `BindableAction` conformance + `BindingReducer()` — matches project template in CLAUDE.md
- Defined `ChallengeAcceptFeature` as a real `@Reducer` (was missing — `ChallengeAcceptState`/`ChallengeAcceptAction` were undefined)
- Added `@Presents var photoCapture: PhotoCaptureState?` — was missing from State but referenced in the photo flow
- Uses `@Dependency(\.anonymousID)` — the existing `AnonymousIDClient` in the codebase provides the anonymous UUID for the validation endpoint
- Shows `.ifLet` composition in body for all `@Presents` children

### ChallengeAcceptFeature (S2 Sheet Reducer)

Was missing from original spec. Defined here:

```swift
@Reducer
struct ChallengeAcceptFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
    }

    enum Action: Sendable {
        case openCameraTapped
        case chooseFromGalleryTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
            case openCamera
            case openGallery
        }
    }
}
```

Lightweight — the view renders challenge details + tips + gold hint + CTAs. Actions delegate up to `DailyChallengeFeature` which dismisses the sheet and presents camera/gallery.

### State Machine Flow

```
idle ──(selectChallenge)──→ available
                               │           │
                            (doIt)      (skip)
                               │           │
                         acceptSheet     skipped
                               │
                       (camera/gallery)
                               │
                         photoCaptured
                               │
                          photoReview
                           │       │
                       (submit)  (retake → camera)
                           │
                       validation (loading → result)
                         │              │
                      valid          invalid
                         │           │      │
                    completed    tryAgain  skipForToday
                         │                    │
                  [level up?]              skipped
                         │
                     levelUp overlay
```

---

## Photo Capture

### PhotoCaptureState (Presentation Enum)

Photo capture is view-level, not a TCA dependency with async closures. The presentation uses `@Presents`:

```swift
enum PhotoCaptureState: Equatable, Sendable, Identifiable {
    case camera
    case gallery

    var id: String {
        switch self {
        case .camera: "camera"
        case .gallery: "gallery"
        }
    }
}

enum PhotoCaptureAction: Sendable {
    case photoCaptured(Data)
    case cancelled
}
```

`DailyChallengeFeature` sets `state.photoCapture = .camera` or `.gallery`. The view layer presents the corresponding `UIViewControllerRepresentable`:

- `.camera` → `CameraPickerRepresentable` wrapping `UIImagePickerController` with `.camera` source, front camera default
- `.gallery` → `GalleryPickerRepresentable` wrapping `PHPickerViewController`, images filter, single selection

Both live in `PhotoCaptureRepresentables.swift` in `Packages/Features/Home/Glow/`.

### Photo Processing

Standalone utility (in `PhotoCaptureRepresentables.swift`):

```swift
enum PhotoProcessor {
    static func process(_ imageData: Data) -> (fullSize: Data, thumbnail: Data)?
}
```

Steps:
1. Decode to `UIImage`
2. Resize longest edge to max 1024px → compress JPEG 0.7 → fullSize (~500KB max)
3. Resize longest edge to 200px → compress JPEG 0.6 → thumbnail (~20KB)

Called after capture/selection, before passing to `PhotoReviewFeature`.

---

## Photo Review (S4)

### PhotoReviewFeature

```swift
@Reducer
struct PhotoReviewFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let imageData: Data
        let thumbnailData: Data
        var isSubmitting: Bool = false
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case submitTapped
        case retakeTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
            case submit(fullSize: Data, thumbnail: Data)
            case retake
        }
    }
}
```

### PhotoReviewView

- Full-bleed photo preview (Image from Data)
- "Aria will check if it matches" subtitle (Raleway Medium, textSecondary)
- "Submit" primary button (glass accent style)
- "Retake" secondary text button

---

## Validation (S5)

### Backend Endpoint

Lives flat in `Packages/Core/Networking/` (no Endpoints/ subdirectory).

Uses `Encodable` body struct matching existing endpoint pattern:

```swift
struct ChallengeValidationRequest: Encodable, Sendable {
    let anonymousId: String
    let challengeType: String
    let challengeDescription: String
    let goldHint: String
    let imageBase64: String
}

struct ChallengeValidationResponse: Decodable, Sendable {
    let valid: Bool
    let rating: String
    let feedback: String
    let xpMultiplier: Double
}

extension Endpoint {
    static func validateChallenge(body: ChallengeValidationRequest) -> Endpoint {
        .post("/api/challenge/validate", body: body)
    }
}
```

The `anonymousId` comes from the existing `AnonymousIDClient` (`@Dependency(\.anonymousID)`), which is already in the codebase at `Packages/Core/Persistence/AnonymousIDClient.swift`.

### ValidationFeature

```swift
@Reducer
struct ValidationFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
        let photoData: Data
        let thumbnailData: Data
        var validationState: ValidationState = .loading

        enum ValidationState: Equatable, Sendable {
            case loading
            case success(ValidationResult)
            case failure(ValidationResult)
        }
    }

    struct ValidationResult: Equatable, Sendable {
        let valid: Bool
        let rating: String
        let feedback: String
        let xpMultiplier: Double
        let xpEarned: Int
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case appeared
        case validationResponse(Result<ChallengeValidationResponse, Error>)
        case dismissTapped
        case tryAgainTapped
        case skipForTodayTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
            case completed(xpEarned: Int, rating: String, feedback: String)
            case tryAgain
            case skipForToday
        }
    }

    @Dependency(\.glowLocal) var glowLocal
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.anonymousID) var anonymousID
}
```

### ValidationResultView

Two phases:

**Loading:** Pulsing circle animation + "Aria is checking..." (Raleway Medium)

**Result (valid):**
- Rating badge animated (RatingBadge component)
  - Gold: confetti particle effect (Canvas-based)
  - Silver: sparkle effect
  - Bronze: subtle warm glow
- AI feedback text (max 2 sentences, Raleway Regular)
- XP count-up animation (0 → earned, using `withAnimation` + Timer)
- Level progress bar (XPProgressBar component)
  - When `isMaxLevel`: shows full bar + "MAX LEVEL" label instead of "N XP to next level"
- "Amazing!" dismiss button (glass style)

**Result (invalid):**
- Gentle AI feedback
- "Try Again" primary → delegate tryAgain
- "Skip for Today" secondary → delegate skipForToday

---

## XP & Level Logic

### GlowConstants

Lives in `Packages/Features/Home/Glow/Components/GlowConstants.swift`.

```swift
enum GlowConstants {
    static let baseXP = 50
    static let consistencyBonus3Days = 30
    static let consistencyBonus7Days = 100

    static let levels: [(level: Int, title: String, xp: Int, emoji: String)] = [
        (1, "Seed", 0, "🌱"),
        (2, "Sprout", 200, "🌿"),
        (3, "Bloom", 500, "🌸"),
        (4, "Flourish", 1_000, "🌺"),
        (5, "Radiant", 2_000, "✨"),
        (6, "Luminous", 3_500, "💫"),
        (7, "Decoded", 5_500, "🔮"),
    ]

    static func levelFor(xp: Int) -> (level: Int, title: String, emoji: String) {
        let match = levels.last(where: { $0.xp <= xp }) ?? levels[0]
        return (match.level, match.title, match.emoji)
    }

    static func xpForNextLevel(currentXP: Int) -> Int? {
        let currentLevel = levelFor(xp: currentXP).level
        guard let next = levels.first(where: { $0.level == currentLevel + 1 }) else { return nil }
        return next.xp - currentXP
    }

    static func xpProgress(currentXP: Int) -> Double {
        let current = levelFor(xp: currentXP)
        guard let nextLevel = levels.first(where: { $0.level == current.level + 1 }) else { return 1.0 }
        let prevXP = levels.first(where: { $0.level == current.level })?.xp ?? 0
        return Double(currentXP - prevXP) / Double(nextLevel.xp - prevXP)
    }
}
```

Changes from original spec:
- Added `emoji` to levels — used in LevelUpOverlay bounce animation
- Added `xpProgress` — returns 0.0-1.0 for `XPProgressBar` fill
- Returns `1.0` at max level — `XPProgressBar` shows full bar

### XP Calculation (in GlowLocalClient.addXP)

1. `finalXP = GlowConstants.baseXP × xpMultiplier` (rounded to Int)
2. Update consistency: if `lastCompletedDate` was yesterday (Calendar.isDateInYesterday) → increment `currentConsistencyDays`, else reset to 1
3. Add consistency bonus: 7+ days → +100 XP, else 3+ days → +30 XP
4. Increment rating count: `goldCount`/`silverCount`/`bronzeCount` based on `rating` parameter
5. Update: `totalXP += finalXP + bonus`, `totalCompleted += 1`, `lastCompletedDate = .now`
6. Update `longestConsistencyDays = max(longestConsistencyDays, currentConsistencyDays)`
7. Recalculate `currentLevel` from `GlowConstants.levelFor(xp: totalXP)`
8. Return `(previousProfile, updatedProfile)` — caller compares `currentLevel` to detect level-up

---

## Level Up Overlay (S9)

### LevelUpFeature

```swift
@Reducer
struct LevelUpFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let newLevel: Int
        let levelTitle: String
        let levelEmoji: String
        let unlockDescription: String
    }

    enum Action: Sendable {
        case appeared
        case dismissTapped
        case autoDismissTimerFired
        case delegate(Delegate)
        enum Delegate: Sendable {
            case dismissed
        }
    }

    @Dependency(\.continuousClock) var clock
}
```

Auto-dismiss after 4 seconds via `clock.sleep`. Haptic `.success` on appear.

### LevelUpOverlay View

- Dimmed blur background (`.ultraThinMaterial` + 0.6 opacity overlay)
- Level emoji bounce animation (scale 0 → 1.2 → 1.0 spring)
- "LEVEL UP!" title (Raleway Bold, 28pt)
- "You're now a {title}" (Raleway SemiBold, 20pt)
- Unlock description (Raleway Regular, textSecondary)
- Tap anywhere to dismiss

### Unlock Descriptions

```
Level 2 (Sprout): "You're growing! Keep going."
Level 3 (Bloom): "Shareable cards unlocked!"
Level 4 (Flourish): "Choose from multiple challenges!"
Level 5 (Radiant): "You're radiant. Keep shining."
Level 6 (Luminous): "Aria now remembers your photos."
Level 7 (Decoded): "Full cycle photo timeline unlocked."
```

---

## Do Card View States (S1)

### DailyChallengeCardView

Replaces the Do card body in CardStackView when a challenge is active.

**State: available**
- Challenge title (Raleway SemiBold, 18pt)
- Challenge description (Raleway Regular, textSecondary, 14pt)
- Phase + Energy tags (small pills with DesignColors.structure background)
- "Do It" primary button (glass accent style, DesignColors.accentWarm)
- "Skip" secondary text button (textSecondary)

**State: completed**
- Photo thumbnail (rounded 12pt, 80x80)
- Rating badge (gold/silver/bronze — RatingBadge component)
- AI feedback text (1-2 lines, Raleway Regular)
- XP earned label ("+{n} XP", Raleway SemiBold, accentWarm)

**State: skipped**
- "Your challenge is here whenever you're ready" (Raleway Regular, textSecondary)
- "Maybe Later" text button → sends `.maybeLaterTapped` → resets to available

### Glass styling

All views use existing DesignSystem components:
- DesignColors palette (background, text, textSecondary, accentWarm, structure)
- Raleway font family (Bold, SemiBold, Medium, Regular)
- `.ultraThinMaterial` for glass effects
- AppLayout spacing constants (horizontalPadding, spacingM, spacingL, cornerRadiusL)
- GlassCardModifier for card containers

---

## Challenge Accept View (S2)

Presented as `.sheet(presentationDetents: [.medium])`.

- Phase icon (from CyclePhase) + challenge title (Raleway Bold, 20pt)
- Challenge description (Raleway Regular, 16pt)
- Context tags row: phase pill, "Day {n}" pill, energy pill (1-5 dots)
- Tips section: 3 bullet points from template (Raleway Regular, 14pt)
- Gold hint: highlighted in warm accent card (Raleway Medium, 14pt)
- XP range: "50-100 XP" (Raleway SemiBold, accentWarm)
- "Open Camera" primary CTA (GlassButton style)
- "Choose from Gallery" secondary text button

---

## File Structure (Corrected to Match Codebase Conventions)

The codebase uses **flat directories** — no Models/, Snapshots/, Clients/, Endpoints/ subdirectories. Only `Glow/` is new (justified: 12+ feature files need separation from the 25 existing files in Home/).

```
Packages/Core/CycleEngine/
├── ChallengeTemplatePool.swift          ~60 lines   (alongside HBICalculator.swift)
├── ChallengeSelector.swift              ~80 lines
└── Resources/challenge_templates.json   ~80 templates

Packages/Core/Persistence/                           (flat, no subdirectories)
├── ChallengeRecord.swift                ~45 lines
├── GlowProfileRecord.swift             ~30 lines
├── ChallengeSnapshot.swift              ~55 lines
├── GlowProfileSnapshot.swift           ~45 lines
└── GlowLocalClient.swift               ~300 lines

Packages/Core/Networking/                            (flat, no subdirectories)
└── ChallengeEndpoints.swift             ~40 lines

Packages/Features/Home/Glow/                         (NEW subdirectory)
├── DailyChallengeFeature.swift          ~250 lines  (coordinator reducer)
├── DailyChallengeCardView.swift         ~150 lines  (Do card 3 states)
├── ChallengeAcceptFeature.swift         ~40 lines   (S2 reducer)
├── ChallengeAcceptView.swift            ~150 lines  (S2 sheet view)
├── PhotoCaptureRepresentables.swift     ~150 lines  (UIImagePicker + PHPicker + PhotoProcessor)
├── PhotoReviewFeature.swift             ~80 lines   (reducer)
├── PhotoReviewView.swift                ~100 lines  (S4)
├── ValidationFeature.swift              ~150 lines  (reducer + response handling)
├── ValidationResultView.swift           ~200 lines  (S5 + animations)
├── LevelUpFeature.swift                 ~60 lines   (reducer)
├── LevelUpOverlay.swift                 ~100 lines  (S9)
└── Components/
    ├── XPProgressBar.swift              ~80 lines   (handles max-level state)
    ├── RatingBadge.swift                ~60 lines
    └── GlowConstants.swift              ~50 lines

Total: ~22 new files, ~1,900 lines estimated
Modifications: CardStackFeature.swift, TodayFeature.swift, CycleDataStore.swift, project.yml (if needed)
```

---

## Integration Checklist

1. Register `ChallengeRecord` + `GlowProfileRecord` in `CycleDataStore.schema` array
2. Run `xcodegen generate` after adding new `Glow/` subdirectory (verify glob pattern covers it)
3. Add `dailyChallengeState: DailyChallengeFeature.State` to `TodayFeature.State`
4. Add `Scope(state:action:)` for `DailyChallengeFeature` in `TodayFeature.body`
5. Add `challengeSnapshot: ChallengeSnapshot?` to `CardStackFeature.State`
6. Add `.challengeDoItTapped`, `.challengeSkipTapped`, `.challengeMaybeLaterTapped` to `CardStackFeature.Delegate`
7. Update `CardStackFeature` `.do` card rendering to use `DailyChallengeCardView` when `challengeSnapshot` is present
8. Route `CardStackFeature` delegate actions through `TodayFeature` → `DailyChallengeFeature`
9. Present `DailyChallengeFeature` sheets/covers in `TodayView`
10. Trigger challenge selection on `phaseResolved` in `TodayFeature`
11. Wire `DailyChallengeFeature.delegate(.challengeStateChanged)` → update `CardStackFeature.State.challengeSnapshot`

---

## Backend Dependency

POST `/api/challenge/validate` must be implemented on the Go backend before the validation flow works end-to-end. The endpoint proxies to GPT-4.1-mini with vision. Photo is processed and discarded immediately, never stored server-side.

For development/testing: the feature gracefully handles API failure by showing "Try Again" or allowing skip. A mock response can be returned from `GlowLocalClient.testValue` for SwiftUI previews.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CycleApp is a premium iOS wellness & menstrual cycle tracking app with an AI companion (Aria). All health data lives exclusively on-device (SwiftData + CloudKit E2E encryption). The Go backend (`dth-backend/`) is a minimal anonymous proxy for Aria chat and Google Places.

- Bundle ID: `app.cycle.ios`
- iCloud Container: `iCloud.app.cycle.ios`
- Design: premium dark-first UI, glass morphism with warm gradients (rose gold, soft purple, peach), spacious layouts, slow elegant animations
- Privacy: "We don't have your data" — zero health data on server

## Build & Development

**Requirements:** Xcode 16.0+, iOS 17.0+, Swift 6.0, XcodeGen (`brew install xcodegen`)

```bash
# Generate Xcode project (required after adding/removing files or editing project.yml)
xcodegen generate

# Build
xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation

# Run tests
xcodebuild test -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' -skipPackagePluginValidation

# Build + install on simulator
./scripts/dev.sh
```

After adding new Swift files or changing the package structure, always re-run `xcodegen generate`.

**IMPORTANT — Flat compilation model:** XcodeGen compiles ALL Swift files from `Packages/Core/` and `Packages/Features/` into a single CycleApp target. Do NOT use `import Models`, `import Persistence`, `import CycleEngine`, or any internal module imports. Only import system frameworks (`Foundation`, `SwiftUI`, `SwiftData`) and external SPM packages (`ComposableArchitecture`, `Inject`, `FirebaseAuth`).

## Architecture

### Local-First Data Architecture

All health data (menstrual cycles, HBI scores, symptoms, daily reports) is stored on-device in SwiftData with CloudKit `encryptedValues` for E2E encrypted multi-device sync. The backend has zero access to health data.

**Data flow:** User input → SwiftData → CycleEngine (local computation) → SwiftData → UI

**Key components:**
- `CycleDataStore` — ModelContainer setup with CloudKit fallback for simulator
- `CycleEngine/` — Pure business logic: HBI calculator, menstrual prediction (V1-V4), cycle math
- Local clients (`HBILocalClient`, `MenstrualLocalClient`, `UserProfileLocalClient`) — TCA dependencies wrapping SwiftData CRUD

### TCA (The Composable Architecture)

Strict Swift 6 concurrency (`SWIFT_STRICT_CONCURRENCY: complete`). Every type must be `Sendable`.

**Feature template:**

```swift
@Reducer
struct MyFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable { }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        enum Delegate: Sendable { }
    }

    @Dependency(\.myClient) var myClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in /* ... */ }
    }
}
```

**Dependency client template:**

```swift
public struct MyClient: Sendable {
    public var doThing: @Sendable (String) async throws -> Response
}

extension MyClient: DependencyKey {
    public static let liveValue = MyClient.live()
    public static let testValue = MyClient.mock()
    public static let previewValue = MyClient.mock()
}

extension DependencyValues {
    public var myClient: MyClient {
        get { self[MyClient.self] }
        set { self[MyClient.self] = newValue }
    }
}
```

**Navigation:** Flat state machine in `AppFeature.State.Destination` enum — no coordinator pattern, no `@Presents` for the main flow. The entire app navigation is a single `switch` on `state.destination`. Child features (Auth, Home) are composed via `Scope`.

**Flow:** `splash → onboarding (14 screens) → authChoice → auth/guest → home`. Returning users: `splash → home` (session check). Guest mode uses same local storage as authenticated — no difference in data handling.

**Home tabs:** Today (TodayFeature), Chat/Aria, Me (profile). Home composes TodayFeature, CycleInsightsFeature, and CycleJourneyFeature as siblings; sibling fan-out is driven by TodayFeature delegate actions (e.g. `cycleDataUpdated`).

**Child feature presentation:** Use `@Presents` in parent State + `.ifLet` in reducer body for modals/sheets/fullScreenCovers. Example: TodayFeature presents DailyCheckInFeature, MoodArcFeature, and WellnessDetailFeature via `@Presents`.

### Package Structure

```
Packages/
├── Core/
│   ├── CycleEngine/      # HBICalculator, MenstrualPredictor (V1-V4), CycleMath utilities
│   ├── Models/           # Tagged IDs, User, Session, CyclePhase, HBIScore, MenstrualStatus types
│   ├── Networking/       # APIClient, Endpoint, FirebaseAuthClient, PlacesClient (Places proxy + Aria WS)
│   ├── Persistence/      # SwiftData Records/, Clients/, CycleDataStore, SessionClient, KeychainClient
│   ├── DesignSystem/     # Tokens/ (DesignColors, AppLayout, Typography) + Components/ grouped by role
│   │                     # (Buttons/, Cards/, Controls/, Hero/, Layout/, Visualizations/, Widgets/, Brand/)
│   └── Utilities/        # Validation, Logger, CycleContext+*, extensions
└── Features/
    ├── App/              # AppFeature (root reducer + navigation state machine)
    ├── Home/             # Each tab/feature in its own subfolder:
    │                     #   Home/          HomeFeature, HomeView (tab shell)
    │                     #   Today/         TodayFeature (+State, +Helpers, +Presentations), YourDayFeature
    │                     #   Calendar/      CalendarFeature, CalendarView, Components/, Sheets/
    │                     #   CycleInsights/ Cycle stats editorial screen + cards
    │                     #   CycleJourney/  Journey list, mandala, recap stories, share preview
    │                     #   DailyCheckIn/  Ritual flow + Aria voice line
    │                     #   EditPeriod/    Period editor + day cells
    │                     #   Wellness/      Wellness detail view
    │                     #   MoodArc/       Standalone mood ritual
    │                     #   Glow/          Challenges/, Levels/, PhotoCapture/, Validation/
    │                     #   Profile/       ProfileFeature + Settings
    │                     #   Chat/          ChatFeature, ChatView
    └── Onboarding/       # 14-screen flow organized by role
                          #   Shell/         OnboardingView, SplashView, backgrounds
                          #   Forms/         Calendar + cycle entry forms
                          #   Permissions/   Privacy consent, HealthKit opt-in
```

### On-Device Data (SwiftData + CloudKit)

All health data stored locally with `@Attribute(.allowsCloudEncryption)` for E2E encrypted iCloud sync.

**SwiftData models** (in `Persistence/`):
- `UserProfileRecord` — identity, birth data, preferences, consent
- `MenstrualProfileRecord` — cycle averages, regularity, symptoms
- `CycleRecord` — individual period records with accuracy tracking
- `SymptomRecord` — daily symptom logs with severity
- `PredictionRecord` — generated predictions with fertile window + confidence
- `SelfReportRecord` — daily check-in (energy, stress, sleep, mood)
- `HBIScoreRecord` — computed HBI with phase-adjusted scoring

**CycleEngine** (pure business logic, no persistence):
- `HBICalculator` — Composite score: Energy 30%, Sleep 25%, Stress 25%, Mood 20% with cycle phase multipliers
- `MenstrualPredictor` — 4 algorithm tiers: V1 Basic → V2 WMA → V3 Ogino-Knaus → V4 ML (seasonal patterns, bias correction)
- `CycleMath` — Statistics, cycle phases, fertile window, confidence scoring

**Local TCA clients:**
- `HBILocalClient` — getDashboard, getToday, submitDailyReport (computes HBI locally)
- `MenstrualLocalClient` — getStatus, getCalendar, confirmPeriod, logSymptom, generatePrediction
- `UserProfileLocalClient` — getProfile, saveProfile, deleteProfile
- `LocalNotificationClient` — daily check-in reminders via UNUserNotificationCenter
- `AriaContextProvider` — builds ephemeral health context for chat messages

### Key Models (cross-package)

- `CyclePhase` enum (menstrual/follicular/ovulatory/luteal) with `orbitColor`, `glowColor`, `gradientColors` — in `Models/HBIDashboard.swift`
- `FlowIntensity` enum (spotting/light/medium/heavy) with `dropletCount` — in `Models/HBIDashboard.swift`
- `MenstrualStatusResponse`, `CycleInfo`, `MenstrualProfileInfo` — in `Models/MenstrualStatus.swift`
- `SymptomType` enum (40+ symptoms with sfSymbol/displayName) — in `Onboarding/CycleModels.swift`

### Key Dependencies

- TCA 1.17+, Tagged 0.10+, Firebase 11+, GoogleSignIn 8+, SplineRuntime, Lottie 4.5+, Inject, HealthKit, SwiftData, CloudKit

## Critical Rules

1. **Sendable everywhere** — all State, Action, models, clients MUST be `Sendable`
2. **No internal module imports** — flat compilation model, everything is in one target
3. **Local-first** — all health data operations use local clients (`hbiLocal`, `menstrualLocal`, `userProfileLocal`), never API calls
4. **SwiftData defaults** — all `@Model` properties must have default values (CloudKit requirement)
5. **DesignSystem first** — use GlassButton, GlassTextField, GlassSelectionCard, GlassCheckbox, DesignColors, AppLayout, AppTypography before creating new components
6. **Tagged IDs** — `Tagged<Model, String>`, never raw String for IDs
7. **Feature split allowed** — reducer/State/view live together by default, but split via `Feature+State.swift`, `Feature+Helpers.swift`, and `FeatureView+Section.swift` extensions when a file crosses ~500 lines. Keep files under that threshold.
8. **Delegate actions** — child→parent communication via `Action.delegate(Delegate)`
9. **State isolation** — capture all state values before `.run { send in }` blocks (Swift 6 `@Sendable` requirement)
10. **Swift Testing** — `@testable import CycleApp` + `import Testing` + `@Test` + `TestStore`, NOT XCTest
11. **Typography** — Raleway family via `AppTypography` tokens (in `DesignSystem/Tokens/Typography.swift`); avoid one-off `.raleway(..., size:)` literals in new code
12. **Screen gutter** — `AppLayout.screenHorizontal` (14pt) is the canonical screen-edge padding for feed/list screens (Today, CycleInsights, CycleJourney, Profile); `AppLayout.horizontalPadding` (32pt) is reserved for ritual/focus screens (Onboarding, MoodArc, DailyCheckIn, Challenges)
13. **Hot reload** — Inject framework is integrated; views use `@ObserveInjection var inject` + `.enableInjection()`

## Testing

```swift
@testable import CycleApp
import Testing

@Test func testFeature() async {
    let store = TestStore(initialState: MyFeature.State()) {
        MyFeature()
    } withDependencies: {
        $0.myClient = .mock()
    }

    await store.send(.buttonTapped) { $0.isLoading = true }
    await store.receive(\.response) { $0.isLoading = false }
}
```

## Backend Quick Reference (Go — `dth-backend/`)

Minimal anonymous proxy — no health data stored.

**Remaining endpoints:**
- `GET /health` — health check
- `GET /firebase-config` — Firebase config for iOS
- `GET /api/places/autocomplete` — Google Places proxy
- `GET /api/places/details` — Google Places proxy
- `WS /ws` — Aria chat WebSocket (messages + RAG memory)

**Architecture:** Gorilla Mux + WebSocket, PostgreSQL (sessions/messages/memory only), Redis (job queue)
**Auth:** Firebase Bearer token middleware (verify only, no user sync)
**Local dev:** `go build -o /tmp/dth-server ./cmd/server/ && /tmp/dth-server`

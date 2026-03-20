# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CycleApp is a premium iOS wellness & menstrual cycle tracking app with an AI companion (Aria). The Go backend lives in a sibling directory (`dth-backend/`).

- Bundle ID: `app.cycle.ios`
- Design: premium dark-first UI, glass morphism with warm gradients (rose gold, soft purple, peach), spacious layouts, slow elegant animations

## Build & Development

**Requirements:** Xcode 16.0+, iOS 17.0+, Swift 6.0, XcodeGen (`brew install xcodegen`)

```bash
# Generate Xcode project (required after adding/removing files or editing project.yml)
xcodegen generate

# Build
xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild test -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16'

# Build + install on simulator
./scripts/dev.sh
```

After adding new Swift files or changing the package structure, always re-run `xcodegen generate`.

## Architecture

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

**Flow:** `splash → onboarding (14 screens) → authChoice → auth/guest → home`. Returning users: `splash → home` (session check).

**Home tabs:** Today (TodayFeature), Chat/Aria (placeholder), Me (profile + logout). Only TodayFeature is a composed child feature; Chat and Me are inline views in HomeFeature.

**Child feature presentation:** Use `@Presents` in parent State + `.ifLet` in reducer body for modals/sheets/fullScreenCovers. Example: CalendarFeature presents EditPeriodFeature via `@Presents public var editPeriod: EditPeriodFeature.State?`.

### Package Structure

```
Packages/
├── Core/
│   ├── Models/           # Tagged IDs, User, Session, API request/response models
│   ├── Networking/       # APIClient, Endpoint, FirebaseAuthClient, domain clients (HBI, Menstrual, Onboarding, Places)
│   ├── Persistence/      # SessionClient, KeychainClient, UserDefaultsClient, OnboardingLocalData
│   ├── DesignSystem/     # DesignColors, AppLayout, Components/ (Glass*, GradientBackground, OnboardingHeader)
│   └── Utilities/        # Validation, Logger, Extensions
└── Features/
    ├── App/              # AppFeature (root reducer + navigation state machine)
    ├── Authentication/   # AuthenticationFeature (login, register, Google sign-in, forgot password)
    ├── Home/             # HomeFeature, TodayFeature, CalendarFeature, EditPeriodFeature, DailyCheckInFeature
    └── Onboarding/       # 14-screen flow + CycleModels enums + Views/
```

### API Integration

- `Endpoint` builder with `.get()`, `.post()`, `.put()`, `.patch()`, `.delete()` static methods
- Auth: `.authenticated(with: token)` extension on `Endpoint`
- Endpoints grouped in `*Endpoints` enums (AuthEndpoints, OnboardingEndpoints, HBIEndpoints, etc.)
- JSON: snake_case encoding/decoding (Go backend), ISO 8601 dates
- Domain clients (HBIClient, MenstrualClient, etc.) wrap `APIClient` and expose typed async methods

### Key Models (cross-package)

- `CyclePhase` enum (menstrual/follicular/ovulatory/luteal) with `orbitColor`, `glowColor`, `gradientColors` — in `Models/HBIDashboard.swift`
- `FlowIntensity` enum (spotting/light/medium/heavy) with `dropletCount` — in `Models/HBIDashboard.swift`
- `MenstrualStatusResponse`, `CycleInfo`, `MenstrualProfileInfo` — in `Models/MenstrualStatus.swift`
- `SymptomType` enum (40+ symptoms with sfSymbol/displayName) — in `Onboarding/CycleModels.swift`

### Key Dependencies

- TCA 1.17+, Tagged 0.10+, Firebase 11+, GoogleSignIn 8+, SplineRuntime, Lottie 4.5+, Inject, HealthKit

## Critical Rules

1. **Sendable everywhere** — all State, Action, models, clients MUST be `Sendable`
2. **DesignSystem first** — use GlassButton, GlassTextField, GlassSelectionCard, DesignColors, AppLayout before creating new components
3. **Tagged IDs** — `Tagged<Model, String>`, never raw String for IDs
4. **Feature + View co-location** — reducer and SwiftUI view live in the same file
5. **Delegate actions** — child→parent communication via `Action.delegate(Delegate)`
6. **State isolation** — capture all state values before `.run { send in }` blocks (Swift 6 `@Sendable` requirement)
7. **Swift Testing** — `import Testing` + `@Test` + `TestStore`, NOT XCTest
8. **Custom font** — Raleway family (Bold, SemiBold, Medium, Regular)
9. **Hot reload** — Inject framework is integrated; views use `@ObserveInjection var inject` + `.enableInjection()`

## Testing

```swift
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

- Architecture: `handler → service → repository` (clean architecture, raw SQL with pgx, no ORM)
- Auth: Firebase Bearer token middleware
- Encryption: AES-256-GCM for PII/medical data at rest
- Key endpoints: `/api/onboarding/screens/*`, `/api/hbi/*`, `/api/menstrual/*`, `/api/self-decode/*`, `/ws` (AI chat)
- JSON tags must match Swift model property names (snake_case)
- Local dev: `go build -o /tmp/dth-server ./cmd/server/ && /tmp/dth-server` (DB via Cloud SQL Proxy on port 5433)
- Context propagation: `context.Context` as first param in service/repo methods
- Parameterized SQL: always `$1, $2`, never string interpolation
- UPSERT pattern: `INSERT ... ON CONFLICT DO UPDATE` for idempotent writes

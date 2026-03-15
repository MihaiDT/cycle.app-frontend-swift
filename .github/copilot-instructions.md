# CycleApp — Copilot Instructions

## Project Overview

CycleApp is a premium iOS wellness & menstrual cycle tracking app with an AI companion (Aria).
Two repos in this workspace:

- **Frontend**: `cycle.app-frontend-swift/` — iOS app (Swift 6, SwiftUI, TCA)
- **Backend**: `dth-backend/` — Go API server (REST + WebSocket)

## Frontend Stack

| Component | Technology |
|---|---|
| UI | SwiftUI (iOS 17+) |
| State management | The Composable Architecture (TCA) 1.17+ |
| Auth | Firebase Auth + Google Sign-In + Anonymous Auth (guest) |
| Networking | URLSession async/await via TCA dependency clients |
| Persistence | Keychain (SessionClient) + UserDefaults |
| Health data | HealthKit |
| Animations | SplineRuntime, Lottie |
| Hot reload | Inject framework |
| Build gen | XcodeGen (project.yml) |
| Concurrency | Swift 6 strict (SWIFT_STRICT_CONCURRENCY: complete) |

## Package Structure

```
Packages/
├── Core/
│   ├── Models/           — User, Session, APIResponse (Tagged IDs)
│   ├── Networking/       — APIClient, Endpoint, FirebaseAuthClient, OnboardingClient, PlacesClient
│   ├── Persistence/      — SessionClient, KeychainClient, UserDefaultsClient
│   ├── DesignSystem/     — DesignColors, AppLayout, Components/ (Glass*, OnboardingLayout)
│   └── Utilities/        — Validation, Logger, Extensions
├── Features/
│   ├── App/              — AppFeature (root reducer, navigation state machine)
│   ├── Authentication/   — AuthenticationFeature (login, register, forgot password)
│   ├── Home/             — HomeFeature (main tab bar)
│   └── Onboarding/       — OnboardingFeature (14+ screens, cycle data collection)
```

## Backend Stack (Go)

| Component | Technology |
|---|---|
| HTTP Router | gorilla/mux |
| Database | PostgreSQL 15 + pgvector (jackc/pgx/v5, NO ORM, raw SQL) |
| Cache | Redis 7 (go-redis/v9) |
| Auth | Firebase Authentication (Bearer token) |
| AI Chat | Anthropic Claude Sonnet 4 (streaming SSE) |
| Embeddings | OpenAI text-embedding-3-small (1536 dim) |
| Encryption | AES-256-GCM (HIPAA — PII/medical data at rest) |
| Architecture | handler → service → repository (clean architecture) |

## Backend Structure

```
cmd/server/main.go          — Cloud Run REST + background jobs
internal/ai/                — Claude API, orchestrator, system prompts
internal/api/               — Handlers: onboarding, costs, places
internal/middleware/         — Firebase auth, CORS, user sync
internal/menstrual/         — Self-contained domain (models, repo, service, handler, calculator)
internal/repository/        — Data access layer (raw SQL)
internal/service/           — Business logic (HBI, Self-Decode, Places)
internal/handler/           — HTTP handlers (HBI, Self-Decode)
internal/crypto/            — AES-256-GCM encryption
internal/rag/               — Embeddings + pgvector similarity search
migrations/                 — SQL up/down migration files
```

## API Endpoints

- `GET /health` — Health check (public)
- `GET /api/places/autocomplete` — Google Places (public)
- `POST /api/onboarding/screens/*` — Onboarding data submission (protected)
- `GET /api/onboarding/progress` — Track onboarding progress (protected)
- `/api/hbi/*` — Health Biomarker Index (protected)
- `/api/self-decode/*` — AI-powered profile generation (protected)
- `/api/menstrual/*` — Menstrual tracking (protected)
- `/ws` — WebSocket for AI chat (protected)

## TCA Pattern (MUST follow)

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
        Reduce { state, action in
            switch action {
            case .binding: return .none
            case .delegate: return .none
            }
        }
    }
}

struct MyFeatureView: View {
    @Bindable var store: StoreOf<MyFeature>
    var body: some View { /* ... */ }
}
```

## Critical Rules

### Swift/Frontend
1. **Sendable everywhere** — all State, Action, models, clients must be Sendable
2. **DesignSystem first** — use existing components (GlassButton, GlassTextField, DesignColors, AppLayout) before creating new ones
3. **Tagged IDs** — use `Tagged<Model, String>`, never raw String for IDs
4. **JSON snake_case** — Go API sends snake_case; use `convertFromSnakeCase` on decoder
5. **Feature + View co-locate** — reducer and view live in the same file
6. **Delegate actions** — child→parent communication via `Action.delegate(Delegate)`
7. **Effects** — use `.run { send in }` with structured concurrency
8. **Tests** — Swift Testing (`import Testing`, `@Test`) + `TestStore`, NOT XCTest
9. **Font** — Custom Raleway font family (Bold, SemiBold, Medium, Regular)

### Go/Backend
1. **handler→service→repository** — never access DB directly from handler
2. **Context propagation** — `context.Context` as first param in service/repo methods
3. **Encrypt PII** — AES-256-GCM before DB storage (emails, names, coordinates, medical data)
4. **Parameterized SQL** — ALWAYS `$1, $2`, NEVER string interpolation
5. **UPSERT pattern** — `INSERT ... ON CONFLICT DO UPDATE` for idempotent writes
6. **Error wrapping** — `fmt.Errorf("context: %w", err)`, never ignore errors
7. **JSON tags must match Swift models**

## Navigation Flow

```
splash → onboarding (14 screens) → paywall → auth/guest → home
```

Returning users: welcome → sign in → home

## Build & Dev

- `xcodegen generate` — regenerate .xcodeproj from project.yml
- `./scripts/dev.sh` — build + install on simulator
- Backend local: `go build -o /tmp/dth-server ./cmd/server/ && /tmp/dth-server`
- DB: PostgreSQL via Cloud SQL Proxy on port 5433
- App bundle ID: `app.cycle.ios`
- Deployment target: iOS 17.0+

## Design Philosophy

- Premium, dark-first UI
- Glass morphism with gradients and subtle blur
- Minimal, spacious layouts (premium feel)
- Slow, elegant animations
- Colors: warm gradients (rose gold, soft purple, peach)

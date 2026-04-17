# CycleApp — Copilot Instructions

## Project Overview

CycleApp is a premium iOS wellness & menstrual cycle tracking app with an AI companion (Aria).
Two repos in this workspace:

- **Frontend** (`cycle.app-frontend-swift/`): Swift 6, SwiftUI, TCA — iOS 17+
- **Backend** (`dth-backend/`): Go, gorilla/mux, PostgreSQL + pgvector, Redis, Firebase Auth

See `CLAUDE.md` for deep reference (dependency client template, key models, API integration details).

## Build & Dev

```bash
# Frontend
xcodegen generate                    # After adding/removing files or editing project.yml
./scripts/dev.sh                     # Build + install on simulator
xcodebuild test -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16'

# Backend
go build -o /tmp/dth-server ./cmd/server/ && /tmp/dth-server   # DB via Cloud SQL Proxy :5433
go test ./...                        # Run all backend tests
go run cmd/migrate/main.go           # Run migrations
```

## Frontend Architecture (Swift 6 / TCA)

### Package Layout

```
Packages/Core/    — Models, Networking, Persistence, DesignSystem, Utilities
Packages/Features — App, Home, Onboarding
```

### TCA Pattern (MUST follow)

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

### Navigation

Flat state machine in `AppFeature.State.Destination` — single `switch` on `state.destination`.
Child features composed via `Scope`. Modals/sheets use `@Presents` + `.ifLet`.

**Flow:** `splash → onboarding (14 screens) → paywall → authChoice → auth/guest → home`
**Returning users:** `splash → home` (session check)

### DesignSystem Components (use before creating new ones)

Glass*: `GlassButton`, `GlassTextField`, `GlassDatePicker`, `GlassDateButton`, `GlassSelectionCard`, `GlassWeekCalendar`
Layout: `GradientBackground`, `OnboardingLayout`, `OnboardingHeader`, `OnboardingProgressBar`, `GradientTagline`
Domain: `CelestialCycleView`, `CyclePhaseBanner`, `HBIScoreRing`, `WellnessPillarCard`, `InsightCard`
Infrastructure: `DesignColors` (color palette), `AppLayout` (spacing), `LiquidGlassModifier` (blur/shadow)
Font: Raleway family (Bold, SemiBold, Medium, Regular)

### Networking Pattern

- Endpoint builder: `.get()`, `.post()`, `.put()`, `.patch()`, `.delete()` → `.authenticated(with: token)`
- Endpoints grouped in `*Endpoints` enums (e.g., `HBIEndpoints.dashboard()`)
- Domain clients (HBIClient, MenstrualClient) wrap `APIClient` with typed async closures
- JSON: snake_case encoding/decoding, ISO 8601 dates with UTC midnight normalization

### Testing

```swift
@Test func testFeature() async {
    let store = TestStore(initialState: MyFeature.State()) {
        MyFeature()
    } withDependencies: { $0.myClient = .mock() }

    await store.send(.buttonTapped) { $0.isLoading = true }
    await store.receive(\.response) { $0.isLoading = false }
}
```

Use `import Testing` + `@Test` + `#expect()` — **never** XCTest.

## Frontend Rules

1. **Sendable everywhere** — all State, Action, models, clients
2. **DesignSystem first** — use existing components listed above before creating new ones
3. **Tagged IDs** — `Tagged<Model, String>`, never raw String
4. **Feature + View co-locate** — reducer and view in the same file
5. **Delegate actions** — child→parent via `Action.delegate(Delegate)`
6. **State isolation** — capture state values before `.run { send in }` (Swift 6 `@Sendable`)
7. **JSON snake_case** — `convertFromSnakeCase` on decoder

## Backend Architecture (Go)

### Structure

```
cmd/server/main.go           — Cloud Run REST + background jobs
cmd/websocket/main.go        — WebSocket server (Compute Engine)
internal/
  ai/                        — Claude API, orchestrator, system prompts
  api/                       — Handlers: onboarding, costs, places
  handler/                   — HTTP handlers: HBI, Self-Decode
  service/                   — Business logic: HBI, Self-Decode, Places
  repository/                — Data access (raw SQL, pgx)
  menstrual/                 — Self-contained domain (models, repo, service, handler, calculator)
  middleware/                — Firebase auth, CORS, user sync
  crypto/                    — AES-256-GCM encryption
  rag/                       — Embeddings + pgvector similarity search
migrations/                  — ###_description.{up,down}.sql (3-digit zero-padded)
```

### Middleware Chain

`Request → BodyLimit (1MB) → CORS → Router → [AuthMiddleware] → Handler → Response`

Auth middleware: validates Firebase Bearer token, syncs user to DB, injects `userID` into context.
Access in handler: `userID := r.Context().Value(middleware.UserIDKey).(string)`

### Error Response Format

```go
utils.RespondError(w, http.StatusBadRequest, "Missing required field")
// → {"error": "Bad Request", "message": "Missing required field", "code": 400}
```

### API Endpoints

Public: `GET /health`, `GET /api/places/autocomplete`
Protected: `/api/onboarding/screens/*`, `/api/hbi/*`, `/api/self-decode/*`, `/api/menstrual/*`, `/ws`

### Environment Variables

Required: `ENCRYPTION_KEY`, `DATABASE_URL`, `FIREBASE_CREDENTIALS`, `CLAUDE_API_KEY`
Optional: `REDIS_URL` (default `redis://localhost:6379`), `PORT` (default `8080`), `ALLOWED_ORIGINS`

## Backend Rules

1. **handler → service → repository** — never access DB from handler
2. **Context propagation** — `context.Context` as first param in service/repo methods
3. **Encrypt PII** — AES-256-GCM before DB storage (emails, names, coordinates, medical data)
4. **Parameterized SQL** — ALWAYS `$1, $2`, NEVER string interpolation
5. **UPSERT pattern** — `INSERT ... ON CONFLICT DO UPDATE` for idempotent writes
6. **Error wrapping** — `fmt.Errorf("context: %w", err)`, never ignore errors
7. **JSON tags must match Swift models** (snake_case)
8. **Migrations** — sequential 3-digit prefix, snake_case, always include `.down.sql`

## Design Philosophy

Premium dark-first UI with glass morphism. Warm gradients (rose gold, soft purple, peach).
Minimal spacious layouts, slow elegant animations. See `DesignColors` for the full palette.

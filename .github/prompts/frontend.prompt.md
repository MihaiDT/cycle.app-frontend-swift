---
mode: agent
description: "🍎 Agent iOS/SwiftUI — Features, DesignSystem, TCA, Networking"
tools: ["terminal", "codebase", "editFiles"]
---

Esti un expert iOS/Swift senior specializat pe SwiftUI si The Composable Architecture (TCA).
Lucrezi pe proiectul **CycleApp** — o aplicatie iOS de wellness si tracking al ciclului menstrual.

# Workspace

- **Frontend**: `cycle.app-frontend-swift/` — iOS app (Swift 6, SwiftUI, TCA)
- **Backend**: `dth-backend/` — Go API (NU modifica fisiere de aici decat daca ti se cere explicit)

# Arhitectura & Stack

| Componenta       | Tehnologie                                                      |
| ---------------- | --------------------------------------------------------------- |
| UI               | SwiftUI (iOS 17+)                                               |
| State management | The Composable Architecture (TCA) 1.17+                         |
| Auth             | Firebase Auth + Google Sign-In                                  |
| Networking       | URLSession async/await via TCA clients                          |
| Persistence      | Keychain (SessionClient) + UserDefaults                         |
| Health data      | HealthKit                                                       |
| Animations       | SplineRuntime, Lottie                                           |
| Hot reload       | Inject framework                                                |
| Build gen        | XcodeGen (project.yml)                                          |
| Linting          | SwiftLint + swift-format                                        |
| Concurrency      | Swift 6 strict concurrency (SWIFT_STRICT_CONCURRENCY: complete) |

# Structura Modulara (SPM Local Packages)

```
Packages/
├── Core/                          # Shared frameworks
│   ├── Models/                    # User, Session, APIResponse — Tagged IDs
│   ├── Networking/                # APIClient, Endpoint, FirebaseAuthClient, OnboardingClient, PlacesClient
│   ├── Persistence/               # SessionClient, KeychainClient, UserDefaultsClient
│   ├── DesignSystem/              # DesignColors, AppLayout, Components/ (Glass*, etc.)
│   └── Utilities/                 # Validation, Logger, Extensions/
├── Features/                      # Ecrane si fluxuri
│   ├── App/                       # AppFeature — root reducer, navigare
│   ├── Authentication/            # AuthenticationFeature — login, register, forgot password
│   ├── Home/                      # HomeFeature — tab bar principal
│   └── Onboarding/                # OnboardingFeature — 17+ ecrane de onboarding
```

# Conventii TCA (OBLIGATORIU)

## Structura unui Feature

```swift
@Reducer
struct MyFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        // proprietati de state
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        // actiuni

        enum Delegate: Sendable {
            // actiuni delegate pentru comunicare child -> parent
        }
    }

    @Dependency(\.myClient) var myClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding: return .none
            case .delegate: return .none
            // handle actions
            }
        }
    }
}
```

## Structura unui TCA Client

```swift
@DependencyClient
struct MyClient: Sendable {
    var doSomething: @Sendable (_ param: String) async throws -> Result
}

extension MyClient: DependencyKey {
    static let liveValue = MyClient(
        doSomething: { param in /* implementare reala */ }
    )
    static let testValue = MyClient()       // unimplemented by default
    static let previewValue = MyClient(
        doSomething: { _ in .mock }
    )
}

extension DependencyValues {
    var myClient: MyClient {
        get { self[MyClient.self] }
        set { self[MyClient.self] = newValue }
    }
}
```

## View-uri

```swift
struct MyFeatureView: View {
    @Bindable var store: StoreOf<MyFeature>

    var body: some View {
        // SwiftUI content
    }
}
```

# Conventii de Naming

| Element        | Pattern                 | Exemplu                            |
| -------------- | ----------------------- | ---------------------------------- |
| Feature        | `<Name>Feature`         | `HomeFeature`, `OnboardingFeature` |
| View           | `<Name>View`            | `HomeView`, `PrivacyConsentView`   |
| Client TCA     | `<Name>Client`          | `APIClient`, `SessionClient`       |
| Model ID       | `Tagged<Model, String>` | `User.ID`, `Session.ID`            |
| Culori         | `DesignColors.<name>`   | `DesignColors.primaryPurple`       |
| Layout         | `AppLayout.<constant>`  | `AppLayout.defaultPadding`         |
| Namespace enum | Caseless enum           | `enum DesignColors { }`            |
| Sectiuni       | `// MARK: - Section`    | `// MARK: - Actions`               |

# Reguli Stricte

1. **Sendable everywhere** — toate State, Action, models si clients trebuie sa fie `Sendable` (Swift 6 strict)
2. **DesignSystem first** — foloseste componentele existente (`GlassButton`, `GlassTextField`, `GlassSelectionCard`, `DesignColors`, `AppLayout`) inainte de a crea altele noi
3. **Tagged IDs** — foloseste `Tagged<Model, String>` pentru type-safe identifiers, nu `String` direct
4. **JSON snake_case <-> camelCase** — API-ul Go trimite snake_case; foloseste `convertFromSnakeCase` / `convertToSnakeCase` pe encoder/decoder
5. **Endpoint pattern** — endpoint-uri noi se adauga ca static factory methods in `Endpoint` (`.get()`, `.post()`, `.put()`) + `.authenticated(with:)`
6. **Mock data** — adauga `.mock` static pe fiecare model nou pentru previews si tests
7. **Feature + View co-locate** — reducer-ul si view-ul stau in acelasi fisier
8. **Delegate actions** — comunicare child -> parent prin `Action.delegate(Delegate)`
9. **Navigation** — enum-based `Destination` in `AppFeature.State`
10. **Access control** — `public` pe module boundaries, `private` pentru implementari interne
11. **Effects** — foloseste `.run { send in }` blocks cu structured concurrency
12. **No XCTest** — foloseste Swift Testing (`import Testing`, `@Test`) + `TestStore`

# Networking cu Backend-ul Go

- Base URL: `https://api.cycle.app`
- Auth: Firebase Bearer token pe toate rutele protejate
- Endpoints principale: `/api/onboarding/*`, `/api/hbi/*`, `/api/self-decode/*`, `/api/menstrual/*`, `/api/places/*`
- Verifica modelele Go din `dth-backend/internal/models/` cand creezi modele Swift noi
- JSON keys trebuie sa fie identice (snake_case in Go tags = ce primeste Swift)

# Build & Dev

- `xcodegen generate` — regenereaza .xcodeproj din project.yml
- `./scripts/dev.sh` — build + install pe simulator
- Deployment target: **iOS 17.0+**
- Xcode 16.0+, Swift 6.0

# Testing

- Framework: **Swift Testing** (`import Testing`, `@Test`, `#expect`)
- TCA: **`TestStore`** cu exhaustive assertions
- Clock: **`ImmediateClock`** injectat pentru teste deterministe
- Directoare: `CycleAppTests/`
- Mock-uri: fiecare client TCA are `testValue`

# Workflow pentru Feature Nou

1. Creaza modelul in `Packages/Core/Models/` (conform `Codable`, `Equatable`, `Sendable`, cu `.mock`)
2. Adauga endpoint-ul in `Packages/Core/Networking/` (Endpoint static factory)
3. Creaza/actualizeaza TCA client-ul in `Packages/Core/Networking/` (live + test + preview)
4. Implementeaza `@Reducer` + View in `Packages/Features/<FeatureName>/`
5. Integreaza in navigare (`AppFeature.Destination`)
6. Adauga teste in `CycleAppTests/` cu `TestStore`

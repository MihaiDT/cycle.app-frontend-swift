---
mode: agent
description: "🔗 Agent Fullstack — Integrare Frontend (Swift/TCA) ↔ Backend (Go)"
tools: ["terminal", "codebase", "editFiles"]
---

Esti un expert fullstack care lucreaza pe ambele parti: iOS (Swift 6/TCA) si Backend (Go).
Proiectul este **CycleApp / DTH** — o aplicatie de wellness si tracking al ciclului menstrual.

# Workspace

- **Frontend**: `cycle.app-frontend-swift/` — iOS app (Swift 6, SwiftUI, TCA)
- **Backend**: `dth-backend/` — Go API server (REST + WebSocket)

# Cand sa ma folosesti

- Feature nou end-to-end (backend endpoint + frontend integration)
- Debugging probleme de comunicare frontend <-> backend
- Sincronizare modele intre Swift si Go
- Verificare compatibilitate API contracts
- Adaugare/modificare flow-uri care implica ambele parti

# Fisiere Cheie de Sincronizat

| Ce              | Frontend (Swift)                                    | Backend (Go)                                                                  |
| --------------- | --------------------------------------------------- | ----------------------------------------------------------------------------- |
| **Modele**      | `Packages/Core/Models/`                             | `internal/models/` + `internal/menstrual/models.go`                           |
| **Endpoints**   | `Packages/Core/Networking/Endpoint.swift`           | `internal/api/` + `internal/handler/`                                         |
| **Auth**        | `Packages/Core/Networking/FirebaseAuthClient.swift` | `internal/firebase/` + `internal/middleware/`                                 |
| **Onboarding**  | `Packages/Core/Networking/OnboardingClient.swift`   | `internal/api/onboarding_handler.go`                                          |
| **HBI**         | (TBD feature)                                       | `internal/handler/hbi_handler.go` + `internal/service/hbi_calculator.go`      |
| **Menstrual**   | (TBD feature)                                       | `internal/menstrual/` (self-contained domain)                                 |
| **Self-Decode** | (TBD feature)                                       | `internal/handler/self_decode_handler.go` + `internal/service/self_decode.go` |

# API Contract Rules

## JSON Serialization

- **Go**: `json:"field_name"` tags (snake_case)
- **Swift**: `JSONDecoder` cu `keyDecodingStrategy = .convertFromSnakeCase`
- **REGULA**: JSON keys din Go tags = sursa de adevar. Swift-ul le converteste automat.

## Tipuri de Date

| Go Type         | JSON               | Swift Type              |
| --------------- | ------------------ | ----------------------- |
| `string`        | `"value"`          | `String`                |
| `int` / `int64` | `123`              | `Int`                   |
| `float64`       | `1.5`              | `Double`                |
| `bool`          | `true`             | `Bool`                  |
| `time.Time`     | `"2024-01-01T..."` | `Date` (ISO 8601)       |
| `*string` (nil) | `null` / absent    | `String?`               |
| `uuid.UUID`     | `"uuid-string"`    | `Tagged<Model, String>` |
| `[]Item`        | `[...]`            | `[Item]`                |

## Auth Flow

1. Frontend: Firebase Auth -> obtine ID token
2. Frontend: trimite `Authorization: Bearer <token>` pe fiecare request
3. Backend: `internal/middleware/auth.go` verifica token-ul cu Firebase Admin SDK
4. Backend: extrage `userID` din token si il pune in `context`
5. Backend: `internal/middleware/user_sync.go` creaza/actualizeaza user-ul in DB

# Workflow pentru Feature Nou End-to-End

## Backend First

1. **Model** — defineste in `internal/models/` cu JSON tags snake_case
2. **Migration** — creaza `migrations/NNN_description.up.sql` + `.down.sql`
3. **Repository** — creaza in `internal/repository/` (raw SQL cu pgx)
4. **Service** — business logic in `internal/service/`
5. **Handler** — HTTP handler in `internal/handler/` sau `internal/api/`
6. **Routes** — inregistreaza ruta in router (cu middleware daca e nevoie)

## Frontend Second

7. **Model Swift** — creaza in `Packages/Core/Models/` (Codable, Equatable, Sendable, .mock)
8. **Endpoint** — adauga static factory method in `Endpoint` (`.get()`, `.post()`)
9. **TCA Client** — creaza/actualizeaza in `Packages/Core/Networking/` (live + test + preview)
10. **Feature** — implementeaza `@Reducer` + View in `Packages/Features/<Name>/`
11. **Navigare** — integreaza in `AppFeature.Destination`
12. **Teste** — `TestStore` in `CycleAppTests/` (frontend) + `go test` (backend)

# Checklist de Compatibilitate

Cand modifici un endpoint sau model, verifica:

- [ ] JSON field names identice intre Go tags si Swift decoder
- [ ] Tipuri nullable (`*type` in Go <-> `Type?` in Swift)
- [ ] Date format ISO 8601 in ambele parti
- [ ] HTTP method si path identice intre `Endpoint.swift` si Go router
- [ ] Auth header trimis pe rute protejate
- [ ] Error responses handled in Swift (status codes 4xx/5xx)
- [ ] Response wrapper consistent (`APIResponse<T>` pattern)

# Debugging Comun

## "Request fails with 401"

- Verifica ca token-ul Firebase e valid si nu e expirat
- Verifica ca header-ul e `Authorization: Bearer <token>` (nu `token` fara Bearer)
- Verifica Firebase middleware in Go

## "JSON decode error in Swift"

- Compara JSON keys din Go response cu Swift model properties
- Verifica daca un field e nullable in Go dar non-optional in Swift
- Check `convertFromSnakeCase` e setat pe decoder

## "Missing field in response"

- Verifica ca field-ul are `json:"..."` tag in Go struct
- Verifica ca field-ul NU e `-` in JSON (omitted)
- Check daca e un pointer nil care devine `null` in JSON -> trebuie optional in Swift

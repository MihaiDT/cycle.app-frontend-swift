---
mode: agent
description: "🔧 Agent Backend Go — API, DB, Services, AI, WebSocket"
tools: ["terminal", "codebase", "editFiles"]
---

Esti un expert Go backend senior.
Lucrezi pe proiectul **DTH Backend (Decode The Hormones)** — API server pentru o aplicatie de wellness si tracking al ciclului menstrual.

# Workspace

- **Backend**: `dth-backend/` — Go API server
- **Frontend**: `cycle.app-frontend-swift/` — iOS client care consuma API-ul (NU modifica fisiere de aici decat daca ti se cere explicit)

# Arhitectura: Layered / Clean Architecture

```
Entry Points (cmd/) -> Middleware -> Handlers/API -> Services -> Repositories -> Infrastructure (DB/Redis/Firebase)
```

Pattern-ul principal: **handler -> service -> repository**

| Layer              | Package                                                                                                           | Responsabilitate                                      |
| ------------------ | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **Entry Points**   | `cmd/server/`, `cmd/api/`, `cmd/websocket/`                                                                       | Bootstrap, DI, HTTP server, graceful shutdown         |
| **Middleware**     | `internal/middleware/`                                                                                            | Firebase auth, CORS, user sync                        |
| **Handlers**       | `internal/handler/`, `internal/api/`                                                                              | HTTP request parsing, validation, response formatting |
| **Services**       | `internal/service/`, `internal/ai/`, `internal/menstrual/`                                                        | Business logic, orchestrare                           |
| **Repositories**   | `internal/repository/`, `internal/menstrual/repository.go`                                                        | Data access, SQL queries, encryption at rest          |
| **Models**         | `internal/models/`, `internal/menstrual/models.go`                                                                | Data structures cu JSON/DB tags                       |
| **Infrastructure** | `internal/db/`, `internal/redis/`, `internal/cache/`, `internal/queue/`, `internal/firebase/`, `internal/crypto/` | Connection pools, caching, queuing, auth, encryption  |

# Stack Tehnic

| Componenta    | Tehnologie                                         |
| ------------- | -------------------------------------------------- |
| HTTP Router   | `gorilla/mux`                                      |
| WebSocket     | `gorilla/websocket` (Hub/Client pattern)           |
| Database      | PostgreSQL 15 + pgvector (`jackc/pgx/v5` pool)     |
| Cache & Queue | Redis 7 (`redis/go-redis/v9`)                      |
| Auth          | Firebase Authentication (Bearer token)             |
| AI Chat       | Anthropic Claude Sonnet 4 (streaming SSE)          |
| Embeddings    | OpenAI text-embedding-3-small (1536 dim, pgvector) |
| Encryption    | AES-256-GCM (PII/medical data at rest)             |
| Logging       | `rs/zerolog` (structured JSON)                     |
| Config        | `joho/godotenv` + environment variables            |
| **No ORM**    | Raw SQL cu `pgx`, parameterized queries            |

# Structura Completa

```
cmd/
  server/main.go        # Primary entry point (Cloud Run REST + background jobs)
  api/main.go            # Lightweight API-only entry point
  websocket/main.go      # WebSocket server (Compute Engine VM)
  migrate/               # Migration runner

internal/
  ai/                    # AI orchestrator, Claude API, system prompts
  analytics/             # Cost tracking (API token usage)
  api/                   # HTTP handlers: onboarding, costs, places
  cache/                 # Redis HBI caching cu TTLs
  config/                # Environment config loader
  crypto/                # AES-256-GCM encryption (HIPAA/PII)
  db/                    # PostgreSQL connection pool + migrations
  firebase/              # Firebase Auth client wrapper
  handler/               # HTTP handlers: HBI, Self-Decode
  jobs/                  # Background job scheduler (cron-like)
  menstrual/             # Self-contained domain: cycles, symptoms, predictions
  middleware/             # Firebase auth middleware, user context injection
  models/                # Core data models (User, Message, Memory, HBI, Session)
  queue/                 # Redis job queue (BRPOP pattern)
  rag/                   # Embeddings + pgvector similarity search
  redis/                 # Redis client
  repository/            # Data access: User, Profile, HBI, Onboarding, SelfDecode, AriaPersona
  service/               # Business logic: HBI calculator, places, Self-Decode, AriaPersona
  utils/                 # HTTP response helpers, logging
  websocket/             # Hub/Client, WebSocket handler
  worker/                # Worker pool (20 workers) async AI processing

migrations/              # SQL up/down migration files
```

# API Patterns

## REST API (port 8080, Cloud Run)

- `gorilla/mux` router cu subrouters
- Firebase Auth middleware pe rute protejate
- JSON request/response (`utils.RespondJSON`, `utils.RespondError`)
- CORS middleware
- Endpoints: `/api/onboarding/*`, `/api/hbi/*`, `/api/self-decode/*`, `/api/menstrual/*`, `/api/places/*`, `/api/costs/*`
- Health check: `/health`

## WebSocket (port 8081, Compute Engine)

- Hub/Client pattern
- Firebase token verification la conectare
- Mesaje enqueuate in Redis, procesate de worker pool
- Raspunsuri AI streamed via WebSocket
- Worker pool: 20 workers cu BRPOP dequeue

## Background Jobs

- HBI calculation (00:30), baseline update (02:00), cycle phase detection (06:00)
- Check-in reminder (20:00), Self-Decode generation (01:00)

# Conventii de Naming

| Element         | Pattern                | Exemplu                                         |
| --------------- | ---------------------- | ----------------------------------------------- |
| Packages        | lowercase, single-word | `handler`, `service`, `repository`              |
| Types           | PascalCase + suffix    | `HBIHandler`, `UserRepository`, `PlacesService` |
| Constructors    | `New<Type>()`          | `NewHBIHandler()`, `NewUserRepository()`        |
| CRUD methods    | PascalCase             | `UpsertUser`, `GetDailySelfReport`              |
| Handler methods | `Handle<Action>`       | `HandleDailyReport`, `HandleConsent`            |
| Constants       | PascalCase             | `CyclePhaseFollicular`, `QueueNameMessages`     |
| Context keys    | Custom `contextKey`    | `UserIDKey`                                     |
| JSON tags       | snake_case             | `json:"energy_level"`                           |
| DB tags         | snake_case             | `db:"user_id"`                                  |
| Files           | snake_case             | `hbi_calculator.go`, `self_decode.go`           |
| Logging         | Emoji prefixes         | ✅ ❌ ⚠️ 🚀                                     |

# Reguli Stricte

1. **handler -> service -> repository** — respecta layering-ul, nu accesa DB direct din handler
2. **Context propagation** — `context.Context` ca prim parametru in repository/service methods
3. **Error handling explicit** — nu ignora erori; wrapping cu `fmt.Errorf("context: %w", err)`
4. **Structured logging** — `zerolog` cu field-based logging (`log.Info().Str("key", val).Msg(...)`)
5. **Encryption at rest** — PII (emails, names, notes, coordinates) => AES-256-GCM inainte de DB storage
6. **UPSERT pattern** — `INSERT ... ON CONFLICT DO UPDATE` pentru idempotent writes
7. **Parameterized queries** — NICIODATA string interpolation in SQL, mereu `$1, $2, ...`
8. **Graceful shutdown** — Signal handling (`SIGINT`/`SIGTERM`) cu timeout contexts
9. **Dependency injection via constructors** — `New<Type>(deps...)`, nu globals
10. **Request/Response co-locate** — structurile de request/response stau langa handler
11. **Models compatibile** — JSON tags trebuie sa fie identice cu modelele Swift din frontend
12. **Migrations** — schema changes via migration files (up/down) in `migrations/`

# Database

## PostgreSQL (pgxpool)

```go
// Connection pool config
pool, err := pgxpool.New(ctx, connString)
// Max 50 conns, 10 min conns
```

## Redis (go-redis)

- HBI caching cu TTLs
- Message queue cu BRPOP pattern
- Session data temporar

## Migrations

- Format: `NNN_description.up.sql` / `NNN_description.down.sql`
- Tool: `cmd/migrate/`
- Mereu creaza si `.down.sql` pentru rollback

# Security

- **Firebase Auth** — Bearer token verification pe fiecare request
- **AES-256-GCM** — encrypt PII/medical inainte de stocare
- **No plaintext PII** in logs
- **CORS** — configurat per environment
- **Parameterized SQL** — prevent SQL injection

# Deployment

- **Cloud Run**: REST API server (Docker multi-stage build, `golang:1.21-alpine`)
- **Compute Engine**: WebSocket server (Docker on VM)
- **Docker Compose**: Local dev cu PostgreSQL (pgvector/pg15) + Redis 7 + Adminer
- **CI/CD**: GitHub Actions -> GCR -> Cloud Run deploy

# Menstrual Domain (Self-contained Module)

`internal/menstrual/` este un modul autonom cu:

- `models.go` — modele proprii (cycle, symptoms, profiles)
- `repository.go` — interface `Repository` + implementare
- `service.go` — interface `Service` + implementare
- `handler.go` — HTTP handlers
- `routes.go` — route registration
- `calculator.go` — cycle calculations
- `middleware.go` — domain-specific middleware
- `utils.go` — helpers

Foloseste `database/sql` cu `lib/pq` (diferit de restul care foloseste `pgx`).

# Workflow pentru Endpoint Nou

1. Defineste modelul in `internal/models/` (cu JSON tags snake_case)
2. Creaza/actualizeaza repository in `internal/repository/` (SQL queries)
3. Adauga business logic in `internal/service/`
4. Creaza handler in `internal/handler/` sau `internal/api/` (validare + response)
5. Inregistreaza ruta in router
6. Adauga middleware daca e nevoie
7. Creaza migration daca schema se schimba (`migrations/NNN_*.up.sql` + `.down.sql`)
8. Verifica compatibilitatea cu modelele Swift din `cycle.app-frontend-swift/Packages/Core/Models/`

# Testing

- Standard `testing` package, table-driven tests cu `t.Run()`
- Test commands: `go test ./...`, `go test -cover ./...`
- `internal/crypto/encryption_test.go` — exemplu de referinta

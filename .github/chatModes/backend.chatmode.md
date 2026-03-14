---
description: "🔧 Backend Go — API, DB, Services, AI, WebSocket"
tools: ["editFiles", "codebase", "terminal", "search"]
---

Esti un expert Go backend senior.
Lucrezi pe proiectul **DTH Backend (Decode The Hormones)** — API server pentru o aplicatie de wellness si tracking al ciclului menstrual.

# Workspace

- **Backend**: `dth-backend/` — Go API server
- **Frontend**: `cycle.app-frontend-swift/` — iOS client (NU modifica fisiere de aici decat daca ti se cere explicit)

# Arhitectura: Layered / Clean Architecture

```
Entry Points (cmd/) -> Middleware -> Handlers/API -> Services -> Repositories -> Infrastructure (DB/Redis/Firebase)
```

Pattern-ul principal: **handler -> service -> repository**

| Layer | Package | Responsabilitate |
|---|---|---|
| Entry Points | `cmd/server/`, `cmd/api/`, `cmd/websocket/` | Bootstrap, DI, HTTP server, graceful shutdown |
| Middleware | `internal/middleware/` | Firebase auth, CORS, user sync |
| Handlers | `internal/handler/`, `internal/api/` | HTTP request parsing, validation, response |
| Services | `internal/service/`, `internal/ai/`, `internal/menstrual/` | Business logic |
| Repositories | `internal/repository/` | Data access, SQL, encryption at rest |
| Models | `internal/models/` | Data structures cu JSON/DB tags |
| Infrastructure | `internal/db/`, `internal/redis/`, `internal/cache/`, `internal/queue/`, `internal/firebase/`, `internal/crypto/` | Pools, caching, auth, encryption |

# Stack Tehnic

| Componenta | Tehnologie |
|---|---|
| HTTP Router | `gorilla/mux` |
| WebSocket | `gorilla/websocket` (Hub/Client pattern) |
| Database | PostgreSQL 15 + pgvector (`jackc/pgx/v5` pool) |
| Cache & Queue | Redis 7 (`redis/go-redis/v9`) |
| Auth | Firebase Authentication (Bearer token) |
| AI Chat | Anthropic Claude Sonnet 4 (streaming SSE) |
| Embeddings | OpenAI text-embedding-3-small (1536 dim) |
| Encryption | AES-256-GCM (PII/medical at rest) |
| Logging | `rs/zerolog` (structured JSON) |
| Config | `joho/godotenv` + env vars |
| **No ORM** | Raw SQL cu `pgx`, parameterized queries |

# Structura

```
cmd/
  server/main.go        # Cloud Run REST + background jobs
  api/main.go            # API-only entry point
  websocket/main.go      # WebSocket server (Compute Engine)
  migrate/               # Migration runner

internal/
  ai/                    # Claude API, system prompts
  analytics/             # Cost tracking
  api/                   # Handlers: onboarding, costs, places
  cache/                 # Redis HBI caching
  config/                # Config loader
  crypto/                # AES-256-GCM encryption
  db/                    # PostgreSQL pool
  firebase/              # Firebase Auth wrapper
  handler/               # Handlers: HBI, Self-Decode
  jobs/                  # Background job scheduler
  menstrual/             # Self-contained domain module
  middleware/             # Auth, user sync
  models/                # Core models
  queue/                 # Redis job queue (BRPOP)
  rag/                   # Embeddings + pgvector search
  redis/                 # Redis client
  repository/            # Data access layer
  service/               # Business logic
  utils/                 # HTTP helpers, logging
  websocket/             # Hub/Client handler
  worker/                # Worker pool (20 workers)

migrations/              # SQL up/down files
```

# Conventii de Naming

| Element | Pattern | Exemplu |
|---|---|---|
| Packages | lowercase, single-word | `handler`, `service`, `repository` |
| Types | PascalCase + suffix | `HBIHandler`, `UserRepository` |
| Constructors | `New<Type>()` | `NewHBIHandler()` |
| Handler methods | `Handle<Action>` | `HandleDailyReport` |
| JSON tags | snake_case | `json:"energy_level"` |
| DB tags | snake_case | `db:"user_id"` |
| Files | snake_case | `hbi_calculator.go` |
| Logging | Emoji prefixes | ✅ ❌ ⚠️ 🚀 |

# Reguli Stricte

1. **handler -> service -> repository** — nu accesa DB direct din handler
2. **Context propagation** — `context.Context` ca prim parametru
3. **Error handling explicit** — `fmt.Errorf("context: %w", err)`
4. **Structured logging** — `zerolog` field-based
5. **Encryption at rest** — PII => AES-256-GCM inainte de DB
6. **UPSERT pattern** — `INSERT ... ON CONFLICT DO UPDATE`
7. **Parameterized queries** — `$1, $2, ...`, NICIODATA string interpolation
8. **Graceful shutdown** — SIGINT/SIGTERM cu timeout
9. **DI via constructors** — `New<Type>(deps...)`, nu globals
10. **Models compatibile** — JSON tags identice cu Swift models
11. **Migrations** — up/down in `migrations/`

# API

- REST port 8080 (Cloud Run), WebSocket port 8081 (Compute Engine)
- Endpoints: `/api/onboarding/*`, `/api/hbi/*`, `/api/self-decode/*`, `/api/menstrual/*`, `/api/places/*`, `/api/costs/*`
- Health: `/health`

# Menstrual Domain

`internal/menstrual/` — modul autonom cu own models, repository (interface), service (interface), handler, routes, calculator. Foloseste `database/sql` cu `lib/pq`.

# Deployment

- Cloud Run: Docker multi-stage (`golang:1.21-alpine`)
- Compute Engine: WebSocket Docker VM
- Docker Compose: local dev (PostgreSQL pgvector + Redis 7 + Adminer)
- CI/CD: GitHub Actions -> GCR -> Cloud Run

# Workflow Endpoint Nou

1. Model in `internal/models/` (JSON tags snake_case)
2. Repository in `internal/repository/` (SQL queries)
3. Service in `internal/service/` (business logic)
4. Handler in `internal/handler/` sau `internal/api/`
5. Ruta in router
6. Migration daca e nevoie (`migrations/NNN_*.up.sql` + `.down.sql`)
7. Verifica compatibilitate cu Swift models

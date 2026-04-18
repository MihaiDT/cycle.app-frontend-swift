# Bonds E2E Crypto Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build E2E encrypted bonds system that lets two users share encrypted wellness summaries — server stores only opaque blobs it cannot read.

**Architecture:** Each device generates a libsodium key pair at app install. Public keys are uploaded to the Go backend. When two users bond, they fetch each other's public keys and use Sealed Box encryption (X25519 + XSalsa20-Poly1305) to encrypt bond summaries client-side. The server is a blind relay — stores and serves encrypted blobs without ever decrypting them. Key recovery uses password-derived encryption (Argon2 + AES) stored as a blob on server.

**Tech Stack:**
- iOS: `swift-sodium` (SPM), Keychain via existing `KeychainClient`
- Go: `pgx/v5`, `gorilla/mux` (existing), new migration + handler
- Crypto: libsodium Sealed Box (X25519 + XSalsa20-Poly1305)
- Storage: PostgreSQL (blobs), Keychain (private keys)

---

## File Structure

### Go Backend (`dth-backend/`)

| File | Action | Responsibility |
|------|--------|---------------|
| `internal/api/bonds.go` | Create | HTTP handlers: create bond, accept, upload/download blobs, upload/get public keys |
| `internal/models/bonds.go` | Create | Bond, BondBlob, PublicKey structs |
| `migrations/047_create_bonds.up.sql` | Create | bonds + public_keys tables |
| `migrations/047_create_bonds.down.sql` | Create | Drop bonds + public_keys |
| `cmd/server/main.go` | Modify | Register bond routes |

### iOS Frontend (`cycle.app-frontend-swift/`)

| File | Action | Responsibility |
|------|--------|---------------|
| `Packages/Core/Persistence/BondCryptoManager.swift` | Create | Key generation, encrypt/decrypt, Keychain storage |
| `Packages/Core/Persistence/BondRecord.swift` | Create | SwiftData model for local bond storage |
| `Packages/Core/Persistence/BondLocalClient.swift` | Create | TCA dependency for bonds CRUD |
| `Packages/Core/Networking/BondEndpoints.swift` | Create | API endpoint definitions |
| `Packages/Core/Models/BondModels.swift` | Create | BondSummary, BondState, BondInvite Codable structs |
| `project.yml` | Modify | Add swift-sodium SPM dependency |

---

## Task 1: Go Backend — Database Migration

**Files:**
- Create: `dth-backend/migrations/047_create_bonds.up.sql`
- Create: `dth-backend/migrations/047_create_bonds.down.sql`

- [ ] **Step 1: Check latest migration number**

```bash
cd ~/Desktop/dth-backend && ls migrations/ | tail -5
```

Adjust `047` to next available number if needed.

- [ ] **Step 2: Create up migration**

```sql
-- 047_create_bonds.up.sql

-- Public keys for E2E encryption
CREATE TABLE IF NOT EXISTS public_keys (
    anonymous_id UUID PRIMARY KEY,
    public_key   BYTEA NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bond connections between two users
CREATE TABLE IF NOT EXISTS bonds (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id     UUID NOT NULL,
    user_b_id     UUID NOT NULL,
    status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'revoked')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_a_id, user_b_id)
);

CREATE INDEX idx_bonds_user_a ON bonds(user_a_id);
CREATE INDEX idx_bonds_user_b ON bonds(user_b_id);

-- Encrypted bond data blobs
CREATE TABLE IF NOT EXISTS bond_blobs (
    id         SERIAL PRIMARY KEY,
    bond_id    UUID NOT NULL REFERENCES bonds(id) ON DELETE CASCADE,
    sender_id  UUID NOT NULL,
    blob_data  BYTEA NOT NULL,
    blob_type  TEXT NOT NULL DEFAULT 'summary' CHECK (blob_type IN ('summary', 'birth_data', 'backup')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(bond_id, sender_id, blob_type)
);

CREATE INDEX idx_bond_blobs_bond_id ON bond_blobs(bond_id);

-- Key recovery blobs (encrypted private key, only user can decrypt with password)
CREATE TABLE IF NOT EXISTS key_recovery (
    anonymous_id   UUID PRIMARY KEY,
    encrypted_key  BYTEA NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

- [ ] **Step 3: Create down migration**

```sql
-- 047_create_bonds.down.sql
DROP TABLE IF EXISTS key_recovery;
DROP TABLE IF EXISTS bond_blobs;
DROP TABLE IF EXISTS bonds;
DROP TABLE IF EXISTS public_keys;
```

- [ ] **Step 4: Verify migration files exist**

```bash
cat migrations/047_create_bonds.up.sql | head -5
cat migrations/047_create_bonds.down.sql | head -2
```

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/dth-backend
git add migrations/047_create_bonds.up.sql migrations/047_create_bonds.down.sql
git commit -m "feat(bonds): add database migrations for bonds, public_keys, bond_blobs, key_recovery tables"
```

---

## Task 2: Go Backend — Models

**Files:**
- Create: `dth-backend/internal/models/bonds.go`

- [ ] **Step 1: Create bond models**

```go
// internal/models/bonds.go
package models

import (
	"time"

	"github.com/google/uuid"
)

// PublicKey stores a user's E2E public key. Server cannot derive private key.
type PublicKey struct {
	AnonymousID uuid.UUID `json:"anonymous_id"`
	PublicKey   []byte    `json:"public_key"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Bond represents an E2E encrypted connection between two users.
type Bond struct {
	ID        uuid.UUID `json:"id"`
	UserAID   uuid.UUID `json:"user_a_id"`
	UserBID   uuid.UUID `json:"user_b_id"`
	Status    string    `json:"status"` // pending, active, revoked
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// BondBlob stores an encrypted data blob. Server cannot read contents.
type BondBlob struct {
	ID        int       `json:"id"`
	BondID    uuid.UUID `json:"bond_id"`
	SenderID  uuid.UUID `json:"sender_id"`
	BlobData  []byte    `json:"blob_data"`
	BlobType  string    `json:"blob_type"` // summary, birth_data, backup
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// KeyRecovery stores an encrypted private key blob. Only the user can decrypt with their password.
type KeyRecovery struct {
	AnonymousID  uuid.UUID `json:"anonymous_id"`
	EncryptedKey []byte    `json:"encrypted_key"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// --- API Request/Response types ---

type UploadPublicKeyRequest struct {
	PublicKey []byte `json:"public_key"`
}

type CreateBondRequest struct {
	PartnerID uuid.UUID `json:"partner_id"`
}

type AcceptBondRequest struct {
	BondID uuid.UUID `json:"bond_id"`
}

type UploadBlobRequest struct {
	BlobData []byte `json:"blob_data"`
	BlobType string `json:"blob_type"`
}

type BondResponse struct {
	Bond      Bond   `json:"bond"`
	PartnerID string `json:"partner_id"`
}

type BondBlobsResponse struct {
	MyBlob      []byte `json:"my_blob,omitempty"`
	PartnerBlob []byte `json:"partner_blob,omitempty"`
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd ~/Desktop/dth-backend && go build ./internal/models/
```

- [ ] **Step 3: Commit**

```bash
git add internal/models/bonds.go
git commit -m "feat(bonds): add Bond, BondBlob, PublicKey, KeyRecovery model structs"
```

---

## Task 3: Go Backend — API Handlers

**Files:**
- Create: `dth-backend/internal/api/bonds.go`

- [ ] **Step 1: Create bonds handler**

```go
// internal/api/bonds.go
package api

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/MihaiDT/dth-backend/internal/models"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

// --- Public Keys ---

// HandleUploadPublicKey stores a user's E2E public key.
func HandleUploadPublicKey(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		var req models.UploadPublicKeyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if len(req.PublicKey) == 0 {
			http.Error(w, "public_key is required", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		_, err = pool.Exec(ctx,
			`INSERT INTO public_keys (anonymous_id, public_key, updated_at)
			 VALUES ($1, $2, NOW())
			 ON CONFLICT (anonymous_id) DO UPDATE SET public_key = $2, updated_at = NOW()`,
			uid, req.PublicKey,
		)
		if err != nil {
			log.Error().Err(err).Str("anonymous_id", anonID).Msg("Failed to upsert public key")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

// HandleGetPublicKey retrieves a user's public key.
func HandleGetPublicKey(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		var pubKey []byte
		err = pool.QueryRow(ctx,
			`SELECT public_key FROM public_keys WHERE anonymous_id = $1`, uid,
		).Scan(&pubKey)
		if err != nil {
			http.Error(w, "public key not found", http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string][]byte{"public_key": pubKey})
	}
}

// --- Bonds ---

// HandleCreateBond creates a pending bond invitation.
func HandleCreateBond(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		var req models.CreateBondRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.PartnerID == uuid.Nil {
			http.Error(w, "partner_id is required", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		bondID := uuid.New()
		_, err = pool.Exec(ctx,
			`INSERT INTO bonds (id, user_a_id, user_b_id, status) VALUES ($1, $2, $3, 'pending')`,
			bondID, uid, req.PartnerID,
		)
		if err != nil {
			log.Error().Err(err).Msg("Failed to create bond")
			http.Error(w, "failed to create bond", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]string{"bond_id": bondID.String(), "status": "pending"})
	}
}

// HandleAcceptBond activates a pending bond.
func HandleAcceptBond(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		bondID, err := uuid.Parse(mux.Vars(r)["bond_id"])
		if err != nil {
			http.Error(w, "invalid bond_id", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		// Only the invited user (user_b) can accept, and only if pending
		tag, err := pool.Exec(ctx,
			`UPDATE bonds SET status = 'active', updated_at = NOW()
			 WHERE id = $1 AND user_b_id = $2 AND status = 'pending'`,
			bondID, uid,
		)
		if err != nil {
			log.Error().Err(err).Msg("Failed to accept bond")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if tag.RowsAffected() == 0 {
			http.Error(w, "bond not found or already accepted", http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"bond_id": bondID.String(), "status": "active"})
	}
}

// HandleUploadBlob stores an encrypted blob for a bond.
func HandleUploadBlob(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		bondID, err := uuid.Parse(mux.Vars(r)["bond_id"])
		if err != nil {
			http.Error(w, "invalid bond_id", http.StatusBadRequest)
			return
		}

		var req models.UploadBlobRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if len(req.BlobData) == 0 {
			http.Error(w, "blob_data is required", http.StatusBadRequest)
			return
		}

		if req.BlobType == "" {
			req.BlobType = "summary"
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		// Verify user is part of this bond and bond is active
		var exists bool
		err = pool.QueryRow(ctx,
			`SELECT EXISTS(
				SELECT 1 FROM bonds
				WHERE id = $1 AND status = 'active'
				AND (user_a_id = $2 OR user_b_id = $2)
			)`, bondID, uid,
		).Scan(&exists)
		if err != nil || !exists {
			http.Error(w, "bond not found or not active", http.StatusForbidden)
			return
		}

		// Upsert blob
		_, err = pool.Exec(ctx,
			`INSERT INTO bond_blobs (bond_id, sender_id, blob_data, blob_type, updated_at)
			 VALUES ($1, $2, $3, $4, NOW())
			 ON CONFLICT (bond_id, sender_id, blob_type)
			 DO UPDATE SET blob_data = $3, updated_at = NOW()`,
			bondID, uid, req.BlobData, req.BlobType,
		)
		if err != nil {
			log.Error().Err(err).Msg("Failed to upload blob")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

// HandleGetBlobs retrieves both users' blobs for a bond.
func HandleGetBlobs(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		bondID, err := uuid.Parse(mux.Vars(r)["bond_id"])
		if err != nil {
			http.Error(w, "invalid bond_id", http.StatusBadRequest)
			return
		}

		blobType := r.URL.Query().Get("type")
		if blobType == "" {
			blobType = "summary"
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		// Verify user is part of bond
		var exists bool
		err = pool.QueryRow(ctx,
			`SELECT EXISTS(
				SELECT 1 FROM bonds
				WHERE id = $1 AND status = 'active'
				AND (user_a_id = $2 OR user_b_id = $2)
			)`, bondID, uid,
		).Scan(&exists)
		if err != nil || !exists {
			http.Error(w, "bond not found", http.StatusForbidden)
			return
		}

		// Get all blobs for this bond and type
		rows, err := pool.Query(ctx,
			`SELECT sender_id, blob_data FROM bond_blobs
			 WHERE bond_id = $1 AND blob_type = $2`,
			bondID, blobType,
		)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		resp := models.BondBlobsResponse{}
		for rows.Next() {
			var senderID uuid.UUID
			var data []byte
			if err := rows.Scan(&senderID, &data); err != nil {
				continue
			}
			if senderID == uid {
				resp.MyBlob = data
			} else {
				resp.PartnerBlob = data
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// HandleGetMyBonds lists all active bonds for a user.
func HandleGetMyBonds(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		rows, err := pool.Query(ctx,
			`SELECT id, user_a_id, user_b_id, status, created_at, updated_at
			 FROM bonds
			 WHERE (user_a_id = $1 OR user_b_id = $1)
			 AND status IN ('pending', 'active')
			 ORDER BY created_at DESC`,
			uid,
		)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		var bonds []models.BondResponse
		for rows.Next() {
			var b models.Bond
			if err := rows.Scan(&b.ID, &b.UserAID, &b.UserBID, &b.Status, &b.CreatedAt, &b.UpdatedAt); err != nil {
				continue
			}
			partnerID := b.UserBID
			if b.UserAID != uid {
				partnerID = b.UserAID
			}
			bonds = append(bonds, models.BondResponse{Bond: b, PartnerID: partnerID.String()})
		}

		if bonds == nil {
			bonds = []models.BondResponse{}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(bonds)
	}
}

// HandleRevokeBond deactivates a bond.
func HandleRevokeBond(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		bondID, err := uuid.Parse(mux.Vars(r)["bond_id"])
		if err != nil {
			http.Error(w, "invalid bond_id", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		// Either user can revoke
		tag, err := pool.Exec(ctx,
			`UPDATE bonds SET status = 'revoked', updated_at = NOW()
			 WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2)`,
			bondID, uid,
		)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if tag.RowsAffected() == 0 {
			http.Error(w, "bond not found", http.StatusNotFound)
			return
		}

		// Delete associated blobs
		pool.Exec(ctx, `DELETE FROM bond_blobs WHERE bond_id = $1`, bondID)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "revoked"})
	}
}

// HandleUploadKeyRecovery stores an encrypted private key backup.
func HandleUploadKeyRecovery(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		var body struct {
			EncryptedKey []byte `json:"encrypted_key"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || len(body.EncryptedKey) == 0 {
			http.Error(w, "encrypted_key is required", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		_, err = pool.Exec(ctx,
			`INSERT INTO key_recovery (anonymous_id, encrypted_key, updated_at)
			 VALUES ($1, $2, NOW())
			 ON CONFLICT (anonymous_id) DO UPDATE SET encrypted_key = $2, updated_at = NOW()`,
			uid, body.EncryptedKey,
		)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

// HandleGetKeyRecovery retrieves the encrypted private key backup.
func HandleGetKeyRecovery(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		anonID := mux.Vars(r)["anonymous_id"]
		uid, err := uuid.Parse(anonID)
		if err != nil {
			http.Error(w, "invalid anonymous_id", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		var encKey []byte
		err = pool.QueryRow(ctx,
			`SELECT encrypted_key FROM key_recovery WHERE anonymous_id = $1`, uid,
		).Scan(&encKey)
		if err != nil {
			http.Error(w, "key recovery not found", http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string][]byte{"encrypted_key": encKey})
	}
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd ~/Desktop/dth-backend && go build ./internal/api/
```

- [ ] **Step 3: Commit**

```bash
git add internal/api/bonds.go
git commit -m "feat(bonds): add all bond HTTP handlers — keys, bonds, blobs, recovery"
```

---

## Task 4: Go Backend — Register Routes

**Files:**
- Modify: `dth-backend/cmd/server/main.go`

- [ ] **Step 1: Add bond routes after existing routes**

Find the section where routes are registered (after `placesHandler.HandleAutocomplete`) and add:

```go
	// --- Bond E2E Encrypted Routes ---
	// Public keys
	router.HandleFunc("/api/{anonymous_id}/keys", api.HandleUploadPublicKey(dbPool)).Methods("PUT")
	router.HandleFunc("/api/{anonymous_id}/keys", api.HandleGetPublicKey(dbPool)).Methods("GET")
	// Key recovery
	router.HandleFunc("/api/{anonymous_id}/key-recovery", api.HandleUploadKeyRecovery(dbPool)).Methods("PUT")
	router.HandleFunc("/api/{anonymous_id}/key-recovery", api.HandleGetKeyRecovery(dbPool)).Methods("GET")
	// Bonds CRUD
	router.HandleFunc("/api/{anonymous_id}/bonds", api.HandleGetMyBonds(dbPool)).Methods("GET")
	router.HandleFunc("/api/{anonymous_id}/bonds", api.HandleCreateBond(dbPool)).Methods("POST")
	router.HandleFunc("/api/{anonymous_id}/bonds/{bond_id}/accept", api.HandleAcceptBond(dbPool)).Methods("POST")
	router.HandleFunc("/api/{anonymous_id}/bonds/{bond_id}/revoke", api.HandleRevokeBond(dbPool)).Methods("DELETE")
	// Bond blobs (encrypted data)
	router.HandleFunc("/api/{anonymous_id}/bonds/{bond_id}/blobs", api.HandleUploadBlob(dbPool)).Methods("PUT")
	router.HandleFunc("/api/{anonymous_id}/bonds/{bond_id}/blobs", api.HandleGetBlobs(dbPool)).Methods("GET")
```

- [ ] **Step 2: Verify full server compiles**

```bash
cd ~/Desktop/dth-backend && go build ./cmd/server/
```

- [ ] **Step 3: Commit**

```bash
git add cmd/server/main.go
git commit -m "feat(bonds): register all bond API routes in REST server"
```

---

## Task 5: iOS — Add swift-sodium dependency

**Files:**
- Modify: `cycle.app-frontend-swift/project.yml`

- [ ] **Step 1: Add swift-sodium to packages section in project.yml**

Find the `packages:` section and add:

```yaml
  Sodium:
    url: https://github.com/jedisct1/swift-sodium.git
    from: "0.9.1"
```

- [ ] **Step 2: Add Sodium to target dependencies**

Find the target dependencies list and add:

```yaml
      - package: Sodium
```

- [ ] **Step 3: Regenerate Xcode project**

```bash
cd ~/Desktop/cycle.app-frontend-swift && xcodegen generate
```

- [ ] **Step 4: Verify build**

```bash
cd ~/Desktop/cycle.app-frontend-swift && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipMacroValidation build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add project.yml CycleApp.xcodeproj
git commit -m "feat(bonds): add swift-sodium SPM dependency for E2E encryption"
```

---

## Task 6: iOS — Bond Crypto Manager

**Files:**
- Create: `cycle.app-frontend-swift/Packages/Core/Persistence/BondCryptoManager.swift`

- [ ] **Step 1: Create BondCryptoManager**

```swift
// Packages/Core/Persistence/BondCryptoManager.swift
import Foundation
import Sodium
import ComposableArchitecture

// MARK: - Bond Crypto Manager

/// Handles all E2E encryption for bonds using libsodium Sealed Box.
/// Private keys never leave the device (stored in Keychain).
/// Server only sees encrypted blobs it cannot read.
public struct BondCryptoManager: Sendable {

    // MARK: - Key Generation

    /// Generate a new key pair. Call once at first launch.
    public var generateKeyPair: @Sendable () throws -> (publicKey: Data, secretKey: Data)

    /// Encrypt data so only the holder of recipientPublicKey can decrypt.
    /// Uses Sealed Box (anonymous sender, X25519 + XSalsa20-Poly1305).
    public var encrypt: @Sendable (_ message: Data, _ recipientPublicKey: Data) throws -> Data

    /// Decrypt data encrypted with our public key.
    public var decrypt: @Sendable (_ encrypted: Data, _ publicKey: Data, _ secretKey: Data) throws -> Data

    /// Encrypt the private key with a password-derived key for server backup.
    public var encryptKeyForRecovery: @Sendable (_ secretKey: Data, _ password: String) throws -> Data

    /// Decrypt the private key from server backup using password.
    public var decryptKeyFromRecovery: @Sendable (_ encryptedKey: Data, _ password: String) throws -> Data
}

// MARK: - Errors

public enum BondCryptoError: Error, Sendable {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidKeyLength
    case passwordDerivationFailed
}

// MARK: - Live Implementation

extension BondCryptoManager: DependencyKey {
    public static let liveValue: BondCryptoManager = {
        let sodium = Sodium()

        return BondCryptoManager(
            generateKeyPair: {
                guard let keyPair = sodium.box.keyPair() else {
                    throw BondCryptoError.keyGenerationFailed
                }
                return (
                    publicKey: Data(keyPair.publicKey),
                    secretKey: Data(keyPair.secretKey)
                )
            },
            encrypt: { message, recipientPublicKey in
                let pubKeyBytes = Array(recipientPublicKey)
                guard let encrypted = sodium.box.seal(
                    message: Array(message),
                    recipientPublicKey: pubKeyBytes
                ) else {
                    throw BondCryptoError.encryptionFailed
                }
                return Data(encrypted)
            },
            decrypt: { encrypted, publicKey, secretKey in
                let encBytes = Array(encrypted)
                let pubBytes = Array(publicKey)
                let secBytes = Array(secretKey)
                guard let decrypted = sodium.box.open(
                    anonymousCipherText: encBytes,
                    recipientPublicKey: pubBytes,
                    recipientSecretKey: secBytes
                ) else {
                    throw BondCryptoError.decryptionFailed
                }
                return Data(decrypted)
            },
            encryptKeyForRecovery: { secretKey, password in
                // Derive a symmetric key from password using Argon2
                let salt = sodium.randomBytes.buf(length: sodium.pwHash.SaltBytes)!
                guard let derivedKey = sodium.pwHash.hash(
                    outputLength: sodium.secretBox.KeyBytes,
                    passwd: Array(password.utf8),
                    salt: salt,
                    opsLimit: sodium.pwHash.OpsLimitModerate,
                    memLimit: sodium.pwHash.MemLimitModerate
                ) else {
                    throw BondCryptoError.passwordDerivationFailed
                }

                guard let encrypted = sodium.secretBox.seal(
                    message: Array(secretKey),
                    secretKey: derivedKey
                ) else {
                    throw BondCryptoError.encryptionFailed
                }

                // Prepend salt so we can re-derive the key later
                return Data(salt + encrypted)
            },
            decryptKeyFromRecovery: { encryptedKey, password in
                let bytes = Array(encryptedKey)
                let saltLength = sodium.pwHash.SaltBytes
                guard bytes.count > saltLength else {
                    throw BondCryptoError.invalidKeyLength
                }

                let salt = Array(bytes.prefix(saltLength))
                let encrypted = Array(bytes.dropFirst(saltLength))

                guard let derivedKey = sodium.pwHash.hash(
                    outputLength: sodium.secretBox.KeyBytes,
                    passwd: Array(password.utf8),
                    salt: salt,
                    opsLimit: sodium.pwHash.OpsLimitModerate,
                    memLimit: sodium.pwHash.MemLimitModerate
                ) else {
                    throw BondCryptoError.passwordDerivationFailed
                }

                guard let decrypted = sodium.secretBox.open(
                    authenticatedCipherText: encrypted,
                    secretKey: derivedKey
                ) else {
                    throw BondCryptoError.decryptionFailed
                }

                return Data(decrypted)
            }
        )
    }()

    public static let testValue = BondCryptoManager(
        generateKeyPair: { (publicKey: Data(repeating: 0xAA, count: 32), secretKey: Data(repeating: 0xBB, count: 32)) },
        encrypt: { message, _ in message },
        decrypt: { encrypted, _, _ in encrypted },
        encryptKeyForRecovery: { secretKey, _ in secretKey },
        decryptKeyFromRecovery: { encrypted, _ in encrypted }
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    public var bondCrypto: BondCryptoManager {
        get { self[BondCryptoManager.self] }
        set { self[BondCryptoManager.self] = newValue }
    }
}
```

- [ ] **Step 2: Regenerate project and verify build**

```bash
cd ~/Desktop/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipMacroValidation build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

- [ ] **Step 3: Commit**

```bash
git add Packages/Core/Persistence/BondCryptoManager.swift CycleApp.xcodeproj
git commit -m "feat(bonds): add BondCryptoManager with libsodium Sealed Box encryption"
```

---

## Task 7: iOS — Bond Models

**Files:**
- Create: `cycle.app-frontend-swift/Packages/Core/Models/BondModels.swift`

- [ ] **Step 1: Create bond value types**

```swift
// Packages/Core/Models/BondModels.swift
import Foundation

// MARK: - Bond Summary (what gets encrypted and shared)

/// Minimal wellness data shared between bonded users.
/// Contains NO identifying information — just phase + scores.
public struct BondSummary: Codable, Sendable, Equatable {
    public let cyclePhase: String      // "menstrual", "follicular", "ovulation", "luteal"
    public let energyLevel: Int        // 1-5
    public let moodLevel: Int          // 1-5
    public let dominantElement: String // "fire", "water", "earth", "air"
    public let tensionScore: Double    // 0.0-1.0
    public let timestamp: Date

    public init(cyclePhase: String, energyLevel: Int, moodLevel: Int,
                dominantElement: String, tensionScore: Double, timestamp: Date = Date()) {
        self.cyclePhase = cyclePhase
        self.energyLevel = energyLevel
        self.moodLevel = moodLevel
        self.dominantElement = dominantElement
        self.tensionScore = tensionScore
        self.timestamp = timestamp
    }
}

// MARK: - Bond State (computed locally from both summaries)

public struct BondState: Codable, Sendable, Equatable {
    public let alignment: Double       // 0.0-1.0 how aligned are they
    public let dominantTheme: String   // "harmony", "tension", "support", "growth"
    public let suggestion: String      // one-line suggestion
    public let timestamp: Date

    public init(alignment: Double, dominantTheme: String, suggestion: String, timestamp: Date = Date()) {
        self.alignment = alignment
        self.dominantTheme = dominantTheme
        self.suggestion = suggestion
        self.timestamp = timestamp
    }
}

// MARK: - Bond Info (local representation)

public struct BondInfo: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let partnerID: String
    public let partnerName: String?
    public let status: BondStatus
    public let createdAt: Date

    public init(id: String, partnerID: String, partnerName: String? = nil,
                status: BondStatus, createdAt: Date) {
        self.id = id
        self.partnerID = partnerID
        self.partnerName = partnerName
        self.status = status
        self.createdAt = createdAt
    }
}

public enum BondStatus: String, Codable, Sendable, Equatable {
    case pending
    case active
    case revoked
}
```

- [ ] **Step 2: Regenerate and verify**

```bash
cd ~/Desktop/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipMacroValidation build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

- [ ] **Step 3: Commit**

```bash
git add Packages/Core/Models/BondModels.swift CycleApp.xcodeproj
git commit -m "feat(bonds): add BondSummary, BondState, BondInfo model types"
```

---

## Task 8: iOS — Bond API Endpoints

**Files:**
- Create: `cycle.app-frontend-swift/Packages/Core/Networking/BondEndpoints.swift`

- [ ] **Step 1: Create endpoint definitions**

```swift
// Packages/Core/Networking/BondEndpoints.swift
import Foundation

// MARK: - Public Key Endpoints

struct UploadPublicKeyEndpoint: Endpoint {
    let anonymousID: String
    let publicKey: Data

    var path: String { "/api/\(anonymousID)/keys" }
    var method: String { "PUT" }
    var body: Data? {
        try? JSONEncoder().encode(["public_key": publicKey.base64EncodedString()])
    }
}

struct GetPublicKeyEndpoint: Endpoint {
    let anonymousID: String

    var path: String { "/api/\(anonymousID)/keys" }
    var method: String { "GET" }
}

// MARK: - Bond Endpoints

struct CreateBondEndpoint: Endpoint {
    let anonymousID: String
    let partnerID: String

    var path: String { "/api/\(anonymousID)/bonds" }
    var method: String { "POST" }
    var body: Data? {
        try? JSONEncoder().encode(["partner_id": partnerID])
    }
}

struct AcceptBondEndpoint: Endpoint {
    let anonymousID: String
    let bondID: String

    var path: String { "/api/\(anonymousID)/bonds/\(bondID)/accept" }
    var method: String { "POST" }
}

struct GetMyBondsEndpoint: Endpoint {
    let anonymousID: String

    var path: String { "/api/\(anonymousID)/bonds" }
    var method: String { "GET" }
}

struct RevokeBondEndpoint: Endpoint {
    let anonymousID: String
    let bondID: String

    var path: String { "/api/\(anonymousID)/bonds/\(bondID)/revoke" }
    var method: String { "DELETE" }
}

// MARK: - Blob Endpoints

struct UploadBlobEndpoint: Endpoint {
    let anonymousID: String
    let bondID: String
    let blobData: Data
    let blobType: String

    var path: String { "/api/\(anonymousID)/bonds/\(bondID)/blobs" }
    var method: String { "PUT" }
    var body: Data? {
        try? JSONEncoder().encode([
            "blob_data": blobData.base64EncodedString(),
            "blob_type": blobType
        ])
    }
}

struct GetBlobsEndpoint: Endpoint {
    let anonymousID: String
    let bondID: String
    let blobType: String

    var path: String { "/api/\(anonymousID)/bonds/\(bondID)/blobs?type=\(blobType)" }
    var method: String { "GET" }
}

// MARK: - Key Recovery Endpoints

struct UploadKeyRecoveryEndpoint: Endpoint {
    let anonymousID: String
    let encryptedKey: Data

    var path: String { "/api/\(anonymousID)/key-recovery" }
    var method: String { "PUT" }
    var body: Data? {
        try? JSONEncoder().encode(["encrypted_key": encryptedKey.base64EncodedString()])
    }
}

struct GetKeyRecoveryEndpoint: Endpoint {
    let anonymousID: String

    var path: String { "/api/\(anonymousID)/key-recovery" }
    var method: String { "GET" }
}
```

- [ ] **Step 2: Verify build**

```bash
cd ~/Desktop/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipMacroValidation build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

- [ ] **Step 3: Commit**

```bash
git add Packages/Core/Networking/BondEndpoints.swift CycleApp.xcodeproj
git commit -m "feat(bonds): add all bond API endpoint definitions"
```

---

## Task 9: iOS — Bond Local Client (TCA Dependency)

**Files:**
- Create: `cycle.app-frontend-swift/Packages/Core/Persistence/BondLocalClient.swift`

- [ ] **Step 1: Create BondLocalClient**

```swift
// Packages/Core/Persistence/BondLocalClient.swift
import ComposableArchitecture
import Foundation

// MARK: - Bond Local Client

/// TCA dependency for managing bonds — key generation, encryption, API calls.
public struct BondLocalClient: Sendable {

    /// Initialize crypto keys if not already done. Call on app launch.
    public var initializeKeys: @Sendable () async throws -> Void

    /// Get our public key (for sharing with server).
    public var getPublicKey: @Sendable () throws -> Data

    /// Create a bond invitation.
    public var createBond: @Sendable (_ partnerID: String) async throws -> BondInfo

    /// Accept a bond invitation.
    public var acceptBond: @Sendable (_ bondID: String) async throws -> BondInfo

    /// List all active bonds.
    public var getMyBonds: @Sendable () async throws -> [BondInfo]

    /// Revoke a bond.
    public var revokeBond: @Sendable (_ bondID: String) async throws -> Void

    /// Encrypt and upload our bond summary.
    public var uploadSummary: @Sendable (_ bondID: String, _ summary: BondSummary) async throws -> Void

    /// Download and decrypt partner's bond summary.
    public var downloadPartnerSummary: @Sendable (_ bondID: String) async throws -> BondSummary?

    /// Backup encrypted private key to server (password-protected).
    public var backupKey: @Sendable (_ password: String) async throws -> Void

    /// Restore private key from server backup.
    public var restoreKey: @Sendable (_ password: String) async throws -> Void
}

// MARK: - Dependency Key

extension BondLocalClient: DependencyKey {
    public static let liveValue = BondLocalClient(
        initializeKeys: { /* TODO: implement in next phase */ },
        getPublicKey: { Data() },
        createBond: { _ in BondInfo(id: "", partnerID: "", status: .pending, createdAt: Date()) },
        acceptBond: { _ in BondInfo(id: "", partnerID: "", status: .active, createdAt: Date()) },
        getMyBonds: { [] },
        revokeBond: { _ in },
        uploadSummary: { _, _ in },
        downloadPartnerSummary: { _ in nil },
        backupKey: { _ in },
        restoreKey: { _ in }
    )

    public static let testValue = BondLocalClient(
        initializeKeys: { },
        getPublicKey: { Data(repeating: 0xAA, count: 32) },
        createBond: { id in BondInfo(id: "test-bond", partnerID: id, status: .pending, createdAt: Date()) },
        acceptBond: { id in BondInfo(id: id, partnerID: "partner", status: .active, createdAt: Date()) },
        getMyBonds: { [] },
        revokeBond: { _ in },
        uploadSummary: { _, _ in },
        downloadPartnerSummary: { _ in nil },
        backupKey: { _ in },
        restoreKey: { _ in }
    )
}

// MARK: - Dependency Values

extension DependencyValues {
    public var bondLocal: BondLocalClient {
        get { self[BondLocalClient.self] }
        set { self[BondLocalClient.self] = newValue }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd ~/Desktop/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipMacroValidation build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

- [ ] **Step 3: Commit**

```bash
git add Packages/Core/Persistence/BondLocalClient.swift CycleApp.xcodeproj
git commit -m "feat(bonds): add BondLocalClient TCA dependency with full API surface"
```

---

## Task 10: Push both branches

- [ ] **Step 1: Push Go backend**

```bash
cd ~/Desktop/dth-backend && git push -u origin feature/bonds-crypto
```

- [ ] **Step 2: Push Swift frontend**

```bash
cd ~/Desktop/cycle.app-frontend-swift && git push -u origin feature/bonds-crypto
```

---

## Summary

After completing all tasks:

**Go Backend has:**
- 4 new tables (public_keys, bonds, bond_blobs, key_recovery)
- 10 API endpoints for bonds CRUD + blob storage + key management
- Zero decryption logic — server is a blind relay

**iOS Frontend has:**
- `swift-sodium` for libsodium crypto
- `BondCryptoManager` — encrypt/decrypt/key generation/recovery
- `BondModels` — BondSummary, BondState, BondInfo
- `BondEndpoints` — all API endpoint definitions
- `BondLocalClient` — TCA dependency (skeleton, live implementation next phase)

**Next phase:** Wire `BondLocalClient.liveValue` to actually call `BondCryptoManager` + `BondEndpoints` + `KeychainClient`, then build the Bond UI feature.

# Persistence — Local-first health data (SwiftData + CloudKit)

## Local-first contract

- All health data lives on-device. The Go backend (`dth-backend/`) has **zero access**. Never add API calls for cycle / period / symptom / HBI / prediction state.
- Backend is only used for: Aria chat (WebSocket), Google Places autocomplete, Firebase config. That's it.
- The `feature/local-first-migration` branch finishes the move; cycle-app is mid-migration. New code targets local clients (`hbiLocal`, `menstrualLocal`, `userProfileLocal`), **NOT** the legacy API clients.

## SwiftData rules

- `@Model` properties **must** have defaults — CloudKit requires it. Optional + default `nil`, or non-optional with a seed value.
- Health-bearing attributes use `@Attribute(.allowsCloudEncryption)` for E2E encrypted iCloud sync. Default-on for: `CycleRecord`, `SymptomRecord`, `PredictionRecord`, `SelfReportRecord`, `HBIScoreRecord`. Profile fields: birth data + cycle averages.
- Don't write `CKDatabase` / `CKRecord` code. SwiftData's CloudKit integration handles sync; conflicts resolve via last-write-wins.
- ModelContainer is owned by `CycleDataStore`. The simulator falls back to an in-memory store (CloudKit is unavailable on sim) — gate setup through `CycleDataStore`, never instantiate `ModelContainer` ad-hoc.

## Local TCA clients

- Clients (`HBILocalClient`, `MenstrualLocalClient`, `UserProfileLocalClient`, `LocalNotificationClient`, `HealthKitLocalClient`) are `Sendable` struct values with `@Sendable` closures, **NOT** actors. Matches the rest of the TCA dependency contract.
- Each client exposes `.live()`, `.mock()`, `.testValue`. `previewValue = .mock()`.
- Live clients capture the `ModelContainer` and route reads/writes through `ModelContext`. Don't expose `ModelContext` to features — the client's API is the boundary.
- Closures are the Swift 6 strict-concurrency cliff — capture all state values **before** the closure body, never reach back through `self`.

## Computation lives in CycleEngine

- Predictions, HBI scores, cycle phase math, fertile window — **computed locally** in `Packages/Core/CycleEngine`. Never bypass the engine to call the API or recompute inline.
- `MenstrualPredictor` has 4 algorithm tiers (V1 Basic → V2 WMA → V3 Ogino-Knaus → V4 ML). Production uses V4 with seasonal patterns + bias correction. Don't hardcode V1 in tests; use the dependency injection point.
- `HBICalculator` weights: Energy 30%, Sleep 25%, Stress 25%, Mood 20%, with cycle phase multipliers. Changing these is a product call, not a refactor.

## IDs

- `Tagged<Model, String>`, never raw `String`. New record types declare their tag in the same file as the record.
- IDs are stable across CloudKit sync — don't generate new ones on read.

## HealthKit

- `HealthKitLocalClient` is the boundary for HKHealthStore reads (HRV, resting HR, wrist temperature). It exposes a `BodySignals` snapshot, never raw `HKQuantitySample`.
- Authorization is requested lazily, not at app launch. The `BodySignalsAccessFlow` two-screen wizard handles the prompt UX.
- HealthKit data is read-only on cycle.app. We don't write back to Health.

## Don't

- Don't add a new `DependencyKey` outside `Packages/Core/Persistence` for health-bearing data. The local client pattern is the contract.
- Don't migrate records by hand — SwiftData handles schema evolution. New properties get defaults; renames go through `@Attribute(originalName:)`.
- Don't ship a `@Model` without an accompanying `Mock` factory in the client's preview/test value. Features need it for previews.

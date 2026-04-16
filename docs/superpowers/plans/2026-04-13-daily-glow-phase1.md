# Daily Glow Phase 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Do card into a daily photo challenge with AI validation, XP rewards, and leveling.

**Architecture:** New `DailyChallengeFeature` coordinator composed into `TodayFeature` via `Scope`. Challenge selection runs locally from bundled templates. Photos captured via system camera/gallery. Validation via backend AI endpoint. XP/level managed in SwiftData.

**Tech Stack:** TCA 1.17+, SwiftData + CloudKit encryption, SwiftUI, UIKit camera/picker wrappers, Swift 6 strict concurrency.

**Spec:** `docs/superpowers/specs/2026-04-13-daily-glow-phase1-design.md`

---

## File Map

### New Files — Core Layer

| File | Responsibility |
|------|---------------|
| `Packages/Core/Persistence/ChallengeRecord.swift` | SwiftData model for challenges |
| `Packages/Core/Persistence/GlowProfileRecord.swift` | SwiftData model for XP/level profile |
| `Packages/Core/Persistence/ChallengeSnapshot.swift` | Immutable value type for TCA state |
| `Packages/Core/Persistence/GlowProfileSnapshot.swift` | Immutable value type for TCA state |
| `Packages/Core/Persistence/GlowLocalClient.swift` | TCA dependency wrapping SwiftData CRUD |
| `Packages/Core/CycleEngine/ChallengeTemplatePool.swift` | Loads + caches templates from bundle |
| `Packages/Core/CycleEngine/ChallengeSelector.swift` | Picks today's challenge from templates |
| `Packages/Core/CycleEngine/Resources/challenge_templates.json` | 80 challenge templates |
| `Packages/Core/Networking/ChallengeEndpoints.swift` | POST /api/challenge/validate |

### New Files — Feature Layer

| File | Responsibility |
|------|---------------|
| `Packages/Features/Home/Glow/GlowConstants.swift` | Levels, XP thresholds, calculations |
| `Packages/Features/Home/Glow/DailyChallengeFeature.swift` | Coordinator reducer — orchestrates full flow |
| `Packages/Features/Home/Glow/DailyChallengeCardView.swift` | Do card 3 states (available/completed/skipped) |
| `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift` | S2 sheet reducer + view |
| `Packages/Features/Home/Glow/PhotoCaptureRepresentables.swift` | UIImagePicker + PHPicker wrappers + PhotoProcessor |
| `Packages/Features/Home/Glow/PhotoReviewFeature.swift` | S4 reducer + view |
| `Packages/Features/Home/Glow/ValidationFeature.swift` | S5 reducer |
| `Packages/Features/Home/Glow/ValidationResultView.swift` | S5 view with rating animations |
| `Packages/Features/Home/Glow/LevelUpFeature.swift` | S9 reducer + overlay view |
| `Packages/Features/Home/Glow/XPProgressBar.swift` | Animated XP bar component |
| `Packages/Features/Home/Glow/RatingBadge.swift` | Gold/silver/bronze badge component |

### Modified Files

| File | Change |
|------|--------|
| `Packages/Core/Persistence/CycleDataStore.swift` | Add 2 models to schema |
| `Packages/Features/Home/CardStackFeature.swift` | Add `challengeSnapshot`, delegate actions, card rendering |
| `Packages/Features/Home/TodayFeature.swift` | Add `DailyChallengeFeature` Scope + routing |

---

## Task 1: GlowConstants — XP & Level Logic

**Files:**
- Create: `Packages/Features/Home/Glow/GlowConstants.swift`

- [ ] **Step 1: Create the Glow/ directory**

```bash
mkdir -p Packages/Features/Home/Glow
```

- [ ] **Step 2: Write GlowConstants**

Create `Packages/Features/Home/Glow/GlowConstants.swift`:

```swift
import Foundation

// MARK: - Glow Constants

enum GlowConstants {
    static let baseXP = 50
    static let consistencyBonus3Days = 30
    static let consistencyBonus7Days = 100

    static let levels: [(level: Int, title: String, xp: Int, emoji: String)] = [
        (1, "Seed", 0, "🌱"),
        (2, "Sprout", 200, "🌿"),
        (3, "Bloom", 500, "🌸"),
        (4, "Flourish", 1_000, "🌺"),
        (5, "Radiant", 2_000, "✨"),
        (6, "Luminous", 3_500, "💫"),
        (7, "Decoded", 5_500, "🔮"),
    ]

    static let unlockDescriptions: [Int: String] = [
        2: "You're growing! Keep going.",
        3: "Shareable cards unlocked!",
        4: "Choose from multiple challenges!",
        5: "You're radiant. Keep shining.",
        6: "Aria now remembers your photos.",
        7: "Full cycle photo timeline unlocked.",
    ]

    static func levelFor(xp: Int) -> (level: Int, title: String, emoji: String) {
        let match = levels.last(where: { $0.xp <= xp }) ?? levels[0]
        return (match.level, match.title, match.emoji)
    }

    static func xpForNextLevel(currentXP: Int) -> Int? {
        let currentLevel = levelFor(xp: currentXP).level
        guard let next = levels.first(where: { $0.level == currentLevel + 1 }) else { return nil }
        return next.xp - currentXP
    }

    /// Returns 0.0–1.0 progress within current level. 1.0 at max level.
    static func xpProgress(currentXP: Int) -> Double {
        let current = levelFor(xp: currentXP)
        guard let nextLevel = levels.first(where: { $0.level == current.level + 1 }) else { return 1.0 }
        let prevXP = levels.first(where: { $0.level == current.level })?.xp ?? 0
        let range = nextLevel.xp - prevXP
        guard range > 0 else { return 1.0 }
        return Double(currentXP - prevXP) / Double(range)
    }

    /// Calculates final XP including consistency bonus.
    static func calculateXP(
        multiplier: Double,
        consecutiveDays: Int
    ) -> (baseXP: Int, bonus: Int, total: Int) {
        let base = Int(Double(baseXP) * multiplier)
        let bonus: Int
        if consecutiveDays >= 7 {
            bonus = consistencyBonus7Days
        } else if consecutiveDays >= 3 {
            bonus = consistencyBonus3Days
        } else {
            bonus = 0
        }
        return (base, bonus, base + bonus)
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Packages/Features/Home/Glow/GlowConstants.swift
git commit -m "feat(glow): add GlowConstants with XP/level logic"
```

---

## Task 2: SwiftData Models

**Files:**
- Create: `Packages/Core/Persistence/ChallengeRecord.swift`
- Create: `Packages/Core/Persistence/GlowProfileRecord.swift`
- Modify: `Packages/Core/Persistence/CycleDataStore.swift:13-25`

- [ ] **Step 1: Create ChallengeRecord**

Create `Packages/Core/Persistence/ChallengeRecord.swift`:

```swift
import Foundation
import SwiftData

// MARK: - Challenge Record

@Model
final class ChallengeRecord {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var date: Date = .now
    @Attribute(.allowsCloudEncryption) var templateId: String = ""
    @Attribute(.allowsCloudEncryption) var challengeCategory: String = ""
    @Attribute(.allowsCloudEncryption) var challengeTitle: String = ""
    @Attribute(.allowsCloudEncryption) var challengeDescription: String = ""
    @Attribute(.allowsCloudEncryption) var tips: String = "[]"
    @Attribute(.allowsCloudEncryption) var goldHint: String = ""
    @Attribute(.allowsCloudEncryption) var validationPrompt: String = ""
    @Attribute(.allowsCloudEncryption) var cyclePhase: String = ""
    @Attribute(.allowsCloudEncryption) var cycleDay: Int = 0
    @Attribute(.allowsCloudEncryption) var energyLevel: Int = 3
    /// "available" | "completed" | "skipped"
    @Attribute(.allowsCloudEncryption) var status: String = "available"
    @Attribute(.allowsCloudEncryption) var completedAt: Date?
    @Attribute(.allowsCloudEncryption) var photoData: Data?
    @Attribute(.allowsCloudEncryption) var photoThumbnail: Data?
    /// "bronze" | "silver" | "gold"
    @Attribute(.allowsCloudEncryption) var validationRating: String?
    @Attribute(.allowsCloudEncryption) var validationFeedback: String?
    @Attribute(.allowsCloudEncryption) var xpEarned: Int = 0
}
```

- [ ] **Step 2: Create GlowProfileRecord**

Create `Packages/Core/Persistence/GlowProfileRecord.swift`:

```swift
import Foundation
import SwiftData

// MARK: - Glow Profile Record

@Model
final class GlowProfileRecord {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var totalXP: Int = 0
    @Attribute(.allowsCloudEncryption) var currentLevel: Int = 1
    @Attribute(.allowsCloudEncryption) var totalCompleted: Int = 0
    @Attribute(.allowsCloudEncryption) var currentConsistencyDays: Int = 0
    @Attribute(.allowsCloudEncryption) var longestConsistencyDays: Int = 0
    @Attribute(.allowsCloudEncryption) var lastCompletedDate: Date?
    @Attribute(.allowsCloudEncryption) var goldCount: Int = 0
    @Attribute(.allowsCloudEncryption) var silverCount: Int = 0
    @Attribute(.allowsCloudEncryption) var bronzeCount: Int = 0
}
```

- [ ] **Step 3: Register models in CycleDataStore**

In `Packages/Core/Persistence/CycleDataStore.swift`, add to the `schema` array (after line 24, before `])`):

```swift
        ChallengeRecord.self,
        GlowProfileRecord.self,
```

The array becomes 13 model types.

- [ ] **Step 4: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Packages/Core/Persistence/ChallengeRecord.swift Packages/Core/Persistence/GlowProfileRecord.swift Packages/Core/Persistence/CycleDataStore.swift
git commit -m "feat(glow): add ChallengeRecord + GlowProfileRecord SwiftData models"
```

---

## Task 3: Snapshots

**Files:**
- Create: `Packages/Core/Persistence/ChallengeSnapshot.swift`
- Create: `Packages/Core/Persistence/GlowProfileSnapshot.swift`

- [ ] **Step 1: Create ChallengeSnapshot**

Create `Packages/Core/Persistence/ChallengeSnapshot.swift`:

```swift
import Foundation

// MARK: - Challenge Snapshot

struct ChallengeSnapshot: Equatable, Sendable {
    let id: UUID
    let date: Date
    let templateId: String
    let challengeCategory: String
    let challengeTitle: String
    let challengeDescription: String
    let tips: [String]
    let goldHint: String
    let validationPrompt: String
    let cyclePhase: String
    let cycleDay: Int
    let energyLevel: Int
    var status: ChallengeStatus
    var completedAt: Date?
    var photoThumbnail: Data?
    var validationRating: String?
    var validationFeedback: String?
    var xpEarned: Int

    enum ChallengeStatus: String, Equatable, Sendable {
        case available
        case completed
        case skipped
    }
}

// MARK: - Record ↔ Snapshot

extension ChallengeSnapshot {
    init(record: ChallengeRecord) {
        let parsedTips = (try? JSONDecoder().decode([String].self, from: Data(record.tips.utf8))) ?? []
        self.init(
            id: record.id,
            date: record.date,
            templateId: record.templateId,
            challengeCategory: record.challengeCategory,
            challengeTitle: record.challengeTitle,
            challengeDescription: record.challengeDescription,
            tips: parsedTips,
            goldHint: record.goldHint,
            validationPrompt: record.validationPrompt,
            cyclePhase: record.cyclePhase,
            cycleDay: record.cycleDay,
            energyLevel: record.energyLevel,
            status: ChallengeStatus(rawValue: record.status) ?? .available,
            completedAt: record.completedAt,
            photoThumbnail: record.photoThumbnail,
            validationRating: record.validationRating,
            validationFeedback: record.validationFeedback,
            xpEarned: record.xpEarned
        )
    }
}
```

- [ ] **Step 2: Create GlowProfileSnapshot**

Create `Packages/Core/Persistence/GlowProfileSnapshot.swift`:

```swift
import Foundation

// MARK: - Glow Profile Snapshot

struct GlowProfileSnapshot: Equatable, Sendable {
    let id: UUID
    var totalXP: Int
    var currentLevel: Int
    var totalCompleted: Int
    var currentConsistencyDays: Int
    var longestConsistencyDays: Int
    var lastCompletedDate: Date?
    var goldCount: Int
    var silverCount: Int
    var bronzeCount: Int

    var levelTitle: String {
        GlowConstants.levelFor(xp: totalXP).title
    }

    var levelEmoji: String {
        GlowConstants.levelFor(xp: totalXP).emoji
    }

    var isMaxLevel: Bool {
        currentLevel >= GlowConstants.levels.last!.level
    }

    static let empty = GlowProfileSnapshot(
        id: UUID(),
        totalXP: 0,
        currentLevel: 1,
        totalCompleted: 0,
        currentConsistencyDays: 0,
        longestConsistencyDays: 0,
        lastCompletedDate: nil,
        goldCount: 0,
        silverCount: 0,
        bronzeCount: 0
    )
}

// MARK: - Record ↔ Snapshot

extension GlowProfileSnapshot {
    init(record: GlowProfileRecord) {
        self.init(
            id: record.id,
            totalXP: record.totalXP,
            currentLevel: record.currentLevel,
            totalCompleted: record.totalCompleted,
            currentConsistencyDays: record.currentConsistencyDays,
            longestConsistencyDays: record.longestConsistencyDays,
            lastCompletedDate: record.lastCompletedDate,
            goldCount: record.goldCount,
            silverCount: record.silverCount,
            bronzeCount: record.bronzeCount
        )
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 4: Commit**

```bash
git add Packages/Core/Persistence/ChallengeSnapshot.swift Packages/Core/Persistence/GlowProfileSnapshot.swift
git commit -m "feat(glow): add ChallengeSnapshot + GlowProfileSnapshot value types"
```

---

## Task 4: GlowLocalClient

**Files:**
- Create: `Packages/Core/Persistence/GlowLocalClient.swift`

**Depends on:** Task 1 (GlowConstants), Task 2 (models), Task 3 (snapshots)

- [ ] **Step 1: Create GlowLocalClient**

Create `Packages/Core/Persistence/GlowLocalClient.swift`:

```swift
import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - Glow Local Client

public struct GlowLocalClient: Sendable {
    public var getTodayChallenge: @Sendable () async throws -> ChallengeSnapshot?
    public var saveChallenge: @Sendable (ChallengeSnapshot) async throws -> Void
    public var completeChallenge: @Sendable (
        _ id: UUID, _ photoData: Data, _ thumbnail: Data,
        _ rating: String, _ feedback: String, _ xpEarned: Int
    ) async throws -> Void
    public var skipChallenge: @Sendable (_ id: UUID) async throws -> Void
    public var getProfile: @Sendable () async throws -> GlowProfileSnapshot
    /// Returns (previous, updated). `rating` updates gold/silver/bronze counts.
    public var addXP: @Sendable (_ amount: Int, _ rating: String) async throws -> (
        previous: GlowProfileSnapshot, current: GlowProfileSnapshot
    )
    public var getRecentCompletedTemplateIds: @Sendable (_ days: Int) async throws -> [String]
}

// MARK: - Dependency

extension GlowLocalClient: DependencyKey {
    public static let liveValue = GlowLocalClient.live()
    public static let testValue = GlowLocalClient.mock()
    public static let previewValue = GlowLocalClient.mock()
}

extension DependencyValues {
    public var glowLocal: GlowLocalClient {
        get { self[GlowLocalClient.self] }
        set { self[GlowLocalClient.self] = newValue }
    }
}

// MARK: - Live

extension GlowLocalClient {
    static func live() -> Self {
        GlowLocalClient(
            getTodayChallenge: {
                let context = ModelContext(CycleDataStore.shared)
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
                let predicate = #Predicate<ChallengeRecord> { record in
                    record.date >= startOfDay && record.date < endOfDay
                }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                guard let record = try context.fetch(descriptor).first else { return nil }
                return ChallengeSnapshot(record: record)
            },

            saveChallenge: { snapshot in
                let context = ModelContext(CycleDataStore.shared)
                let record = ChallengeRecord()
                record.id = snapshot.id
                record.date = snapshot.date
                record.templateId = snapshot.templateId
                record.challengeCategory = snapshot.challengeCategory
                record.challengeTitle = snapshot.challengeTitle
                record.challengeDescription = snapshot.challengeDescription
                record.tips = (try? String(data: JSONEncoder().encode(snapshot.tips), encoding: .utf8)) ?? "[]"
                record.goldHint = snapshot.goldHint
                record.validationPrompt = snapshot.validationPrompt
                record.cyclePhase = snapshot.cyclePhase
                record.cycleDay = snapshot.cycleDay
                record.energyLevel = snapshot.energyLevel
                record.status = snapshot.status.rawValue
                context.insert(record)
                try context.save()
            },

            completeChallenge: { id, photoData, thumbnail, rating, feedback, xpEarned in
                let context = ModelContext(CycleDataStore.shared)
                let predicate = #Predicate<ChallengeRecord> { $0.id == id }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                guard let record = try context.fetch(descriptor).first else { return }
                record.status = "completed"
                record.completedAt = Date()
                record.photoData = photoData
                record.photoThumbnail = thumbnail
                record.validationRating = rating
                record.validationFeedback = feedback
                record.xpEarned = xpEarned
                try context.save()
            },

            skipChallenge: { id in
                let context = ModelContext(CycleDataStore.shared)
                let predicate = #Predicate<ChallengeRecord> { $0.id == id }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                guard let record = try context.fetch(descriptor).first else { return }
                record.status = "skipped"
                try context.save()
            },

            getProfile: {
                let context = ModelContext(CycleDataStore.shared)
                let descriptor = FetchDescriptor<GlowProfileRecord>()
                if let record = try context.fetch(descriptor).first {
                    return GlowProfileSnapshot(record: record)
                }
                // Create singleton profile on first access
                let record = GlowProfileRecord()
                context.insert(record)
                try context.save()
                return GlowProfileSnapshot(record: record)
            },

            addXP: { amount, rating in
                let context = ModelContext(CycleDataStore.shared)
                let descriptor = FetchDescriptor<GlowProfileRecord>()
                let record: GlowProfileRecord
                if let existing = try context.fetch(descriptor).first {
                    record = existing
                } else {
                    record = GlowProfileRecord()
                    context.insert(record)
                }

                let previous = GlowProfileSnapshot(record: record)

                // Update consistency
                if let lastDate = record.lastCompletedDate,
                   Calendar.current.isDateInYesterday(lastDate)
                {
                    record.currentConsistencyDays += 1
                } else {
                    record.currentConsistencyDays = 1
                }

                // Calculate bonus
                let bonus: Int
                if record.currentConsistencyDays >= 7 {
                    bonus = GlowConstants.consistencyBonus7Days
                } else if record.currentConsistencyDays >= 3 {
                    bonus = GlowConstants.consistencyBonus3Days
                } else {
                    bonus = 0
                }

                // Update totals
                record.totalXP += amount + bonus
                record.totalCompleted += 1
                record.lastCompletedDate = Date()
                record.longestConsistencyDays = max(
                    record.longestConsistencyDays,
                    record.currentConsistencyDays
                )

                // Update rating counts
                switch rating {
                case "gold": record.goldCount += 1
                case "silver": record.silverCount += 1
                case "bronze": record.bronzeCount += 1
                default: break
                }

                // Recalculate level
                record.currentLevel = GlowConstants.levelFor(xp: record.totalXP).level

                try context.save()
                let current = GlowProfileSnapshot(record: record)
                return (previous, current)
            },

            getRecentCompletedTemplateIds: { days in
                let context = ModelContext(CycleDataStore.shared)
                let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
                let predicate = #Predicate<ChallengeRecord> { record in
                    record.status == "completed" && record.date >= cutoff
                }
                let descriptor = FetchDescriptor(predicate: predicate)
                let records = try context.fetch(descriptor)
                return records.map(\.templateId)
            }
        )
    }
}

// MARK: - Mock

extension GlowLocalClient {
    static func mock() -> Self {
        GlowLocalClient(
            getTodayChallenge: { nil },
            saveChallenge: { _ in },
            completeChallenge: { _, _, _, _, _, _ in },
            skipChallenge: { _ in },
            getProfile: { .empty },
            addXP: { _, _ in (.empty, .empty) },
            getRecentCompletedTemplateIds: { _ in [] }
        )
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Packages/Core/Persistence/GlowLocalClient.swift
git commit -m "feat(glow): add GlowLocalClient with SwiftData CRUD operations"
```

---

## Task 5: Challenge Templates + Selector

**Files:**
- Create: `Packages/Core/CycleEngine/ChallengeTemplatePool.swift`
- Create: `Packages/Core/CycleEngine/ChallengeSelector.swift`
- Create: `Packages/Core/CycleEngine/Resources/challenge_templates.json`

- [ ] **Step 1: Create ChallengeTemplatePool**

Create `Packages/Core/CycleEngine/ChallengeTemplatePool.swift`:

```swift
import Foundation

// MARK: - Challenge Template

struct ChallengeTemplate: Codable, Sendable {
    let id: String
    let category: String
    let phases: [String]
    let energyMin: Int
    let energyMax: Int
    let title: String
    let description: String
    let tips: [String]
    let goldHint: String
    let validationPrompt: String
}

// MARK: - Challenge Template Pool

enum ChallengeTemplatePool {
    private static var cached: [ChallengeTemplate]?

    static var templates: [ChallengeTemplate] {
        if let cached { return cached }
        guard let url = Bundle.main.url(forResource: "challenge_templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ChallengeTemplate].self, from: data)
        else {
            return []
        }
        cached = decoded
        return decoded
    }
}
```

- [ ] **Step 2: Create ChallengeSelector**

Create `Packages/Core/CycleEngine/ChallengeSelector.swift`:

```swift
import Foundation

// MARK: - Challenge Selector

enum ChallengeSelector {
    /// Select a challenge template matching current phase, energy, excluding recent.
    static func select(
        phase: String,
        energyLevel: Int,
        recentTemplateIds: [String],
        templates: [ChallengeTemplate]
    ) -> ChallengeTemplate? {
        let nonRecent = templates.filter { !recentTemplateIds.contains($0.id) }

        // Phase + energy match (excluding recent)
        let phaseAndEnergy = nonRecent.filter { template in
            template.phases.contains(phase)
                && energyLevel >= template.energyMin
                && energyLevel <= template.energyMax
        }
        if let pick = phaseAndEnergy.randomElement() {
            return pick
        }

        // Relax energy — phase only (excluding recent)
        let phaseOnly = nonRecent.filter { $0.phases.contains(phase) }
        if let pick = phaseOnly.randomElement() {
            return pick
        }

        // Any non-recent template
        if let pick = nonRecent.randomElement() {
            return pick
        }

        // Last resort — any template at all
        return templates.randomElement()
    }
}
```

- [ ] **Step 3: Create challenge_templates.json**

Create `Packages/Core/CycleEngine/Resources/challenge_templates.json` with 80 templates. The file is a JSON array of `ChallengeTemplate` objects. Here is the structure — populate with 80 entries across all 6 categories (social, self_care, creative, movement, mindfulness, nutrition) × 4 phases (menstrual, follicular, ovulatory, luteal) × energy levels 1-5:

```json
[
  {
    "id": "social_ovulatory_01",
    "category": "social",
    "phases": ["ovulatory", "follicular"],
    "energyMin": 3,
    "energyMax": 5,
    "title": "Friend selfie time",
    "description": "Go out with a friend and take a selfie together",
    "tips": ["Pick your favorite person", "Try a fun location", "Show genuine smiles"],
    "goldHint": "Dress up, fun location, genuine smiles",
    "validationPrompt": "Photo should show two or more people taking a selfie together. They should look happy and social."
  },
  {
    "id": "self_care_menstrual_01",
    "category": "self_care",
    "phases": ["menstrual", "luteal"],
    "energyMin": 1,
    "energyMax": 3,
    "title": "Cozy comfort zone",
    "description": "Make yourself a warm drink and show us your comfort setup",
    "tips": ["Tea, coffee, or hot chocolate", "Blankets count", "Your favorite spot"],
    "goldHint": "Cozy blanket, warm drink, peaceful setting",
    "validationPrompt": "Photo should show a cozy setup with a warm beverage. Comfort items like blankets or pillows are a plus."
  },
  {
    "id": "creative_follicular_01",
    "category": "creative",
    "phases": ["follicular", "ovulatory"],
    "energyMin": 2,
    "energyMax": 5,
    "title": "Fresh makeup look",
    "description": "Try a new makeup look or hairstyle and show us the result",
    "tips": ["Try something you've never done", "Good lighting helps", "Confidence is key"],
    "goldHint": "Creative, bold, well-executed look",
    "validationPrompt": "Photo should show a person with a clearly intentional makeup look or hairstyle. Creativity and effort matter more than perfection."
  },
  {
    "id": "movement_follicular_01",
    "category": "movement",
    "phases": ["follicular", "ovulatory"],
    "energyMin": 3,
    "energyMax": 5,
    "title": "Get moving",
    "description": "Do any form of exercise and capture a post-workout photo",
    "tips": ["Any movement counts", "Show your workout spot", "Post-workout glow is real"],
    "goldHint": "Visible effort, workout gear, energetic vibe",
    "validationPrompt": "Photo should show evidence of physical activity — workout clothes, gym, outdoor exercise, or a clearly post-workout selfie."
  },
  {
    "id": "mindfulness_luteal_01",
    "category": "mindfulness",
    "phases": ["luteal", "menstrual"],
    "energyMin": 1,
    "energyMax": 4,
    "title": "Peaceful moment",
    "description": "Find a quiet spot and capture a moment of peace",
    "tips": ["Nature, a quiet room, anywhere calm", "Focus on what makes you feel at ease", "Take a deep breath first"],
    "goldHint": "Beautiful, serene setting with intentional composition",
    "validationPrompt": "Photo should convey a sense of peace and calm — a quiet natural setting, a meditation space, a serene view, or a mindful moment."
  },
  {
    "id": "nutrition_follicular_01",
    "category": "nutrition",
    "phases": ["follicular", "ovulatory", "luteal"],
    "energyMin": 2,
    "energyMax": 5,
    "title": "Nourish yourself",
    "description": "Prepare a healthy meal or snack and show us the plate",
    "tips": ["Colors make it pop", "Homemade is great", "Presentation matters"],
    "goldHint": "Colorful, well-plated, clearly healthy food",
    "validationPrompt": "Photo should show food that appears healthy and intentionally prepared. Presentation and color variety indicate gold quality."
  }
]
```

**IMPORTANT:** The implementer must expand this to ~80 templates. Use these 6 as the pattern and create ~12-14 per category, covering all phase combinations and energy ranges. Each template needs a unique `id` in the format `{category}_{phase}_{number}`.

- [ ] **Step 4: Add Resources to project.yml if needed**

Check if XcodeGen picks up the `Resources/` subdirectory. If the `Packages/Core/CycleEngine/` source glob already covers JSON files, no change needed. If not, add a resources entry in `project.yml` under the CycleApp target:

```yaml
resources:
  - path: Packages/Core/CycleEngine/Resources
    type: folder
```

- [ ] **Step 5: Verify it compiles and JSON loads**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 6: Commit**

```bash
git add Packages/Core/CycleEngine/ChallengeTemplatePool.swift Packages/Core/CycleEngine/ChallengeSelector.swift Packages/Core/CycleEngine/Resources/
git commit -m "feat(glow): add challenge template pool + selector engine"
```

---

## Task 6: Networking — Validation Endpoint

**Files:**
- Create: `Packages/Core/Networking/ChallengeEndpoints.swift`

- [ ] **Step 1: Create endpoint with request/response types**

Create `Packages/Core/Networking/ChallengeEndpoints.swift`:

```swift
import Foundation

// MARK: - Challenge Validation

struct ChallengeValidationRequest: Encodable, Sendable {
    let anonymousId: String
    let challengeType: String
    let challengeDescription: String
    let goldHint: String
    let imageBase64: String
}

struct ChallengeValidationResponse: Decodable, Sendable {
    let valid: Bool
    let rating: String
    let feedback: String
    let xpMultiplier: Double
}

extension Endpoint {
    static func validateChallenge(body: ChallengeValidationRequest) -> Endpoint {
        .post("/api/challenge/validate", body: body)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Packages/Core/Networking/ChallengeEndpoints.swift
git commit -m "feat(glow): add challenge validation endpoint"
```

---

## Task 7: UI Components — RatingBadge + XPProgressBar

**Files:**
- Create: `Packages/Features/Home/Glow/RatingBadge.swift`
- Create: `Packages/Features/Home/Glow/XPProgressBar.swift`

- [ ] **Step 1: Create RatingBadge**

Create `Packages/Features/Home/Glow/RatingBadge.swift`:

```swift
import SwiftUI

// MARK: - Rating Badge

struct RatingBadge: View {
    let rating: String
    var size: CGFloat = 32
    var animated: Bool = false

    @State private var scale: CGFloat = 0

    private var emoji: String {
        switch rating {
        case "gold": "🥇"
        case "silver": "🥈"
        case "bronze": "🥉"
        default: "⭐"
        }
    }

    private var label: String {
        rating.capitalized
    }

    private var badgeColor: Color {
        switch rating {
        case "gold": Color(red: 1.0, green: 0.84, blue: 0.0)
        case "silver": Color(red: 0.75, green: 0.75, blue: 0.78)
        case "bronze": Color(red: 0.80, green: 0.50, blue: 0.20)
        default: DesignColors.accentWarm
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: size * 0.6))
            Text(label)
                .font(.custom("Raleway-SemiBold", size: size * 0.45))
                .foregroundStyle(DesignColors.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(badgeColor.opacity(0.15))
                .overlay {
                    Capsule()
                        .strokeBorder(badgeColor.opacity(0.3), lineWidth: 1)
                }
        }
        .scaleEffect(animated ? scale : 1)
        .onAppear {
            guard animated else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1
            }
        }
    }
}
```

- [ ] **Step 2: Create XPProgressBar**

Create `Packages/Features/Home/Glow/XPProgressBar.swift`:

```swift
import SwiftUI

// MARK: - XP Progress Bar

struct XPProgressBar: View {
    let currentXP: Int
    let animated: Bool

    @State private var displayProgress: Double = 0

    private var progress: Double {
        GlowConstants.xpProgress(currentXP: currentXP)
    }

    private var isMaxLevel: Bool {
        GlowConstants.xpForNextLevel(currentXP: currentXP) == nil
    }

    private var levelInfo: (level: Int, title: String, emoji: String) {
        GlowConstants.levelFor(xp: currentXP)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Level label
            HStack {
                Text("\(levelInfo.emoji) \(levelInfo.title)")
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundStyle(DesignColors.text)

                Spacer()

                if isMaxLevel {
                    Text("MAX LEVEL")
                        .font(.custom("Raleway-Bold", size: 12))
                        .foregroundStyle(DesignColors.accentWarm)
                } else if let remaining = GlowConstants.xpForNextLevel(currentXP: currentXP) {
                    Text("\(remaining) XP to next level")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundStyle(DesignColors.textSecondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignColors.structure.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [DesignColors.accentWarm, DesignColors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * displayProgress)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    displayProgress = progress
                }
            } else {
                displayProgress = progress
            }
        }
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 4: Commit**

```bash
git add Packages/Features/Home/Glow/RatingBadge.swift Packages/Features/Home/Glow/XPProgressBar.swift
git commit -m "feat(glow): add RatingBadge + XPProgressBar components"
```

---

## Task 8: Photo Capture — UIKit Wrappers

**Files:**
- Create: `Packages/Features/Home/Glow/PhotoCaptureRepresentables.swift`

- [ ] **Step 1: Create camera picker, gallery picker, and photo processor**

Create `Packages/Features/Home/Glow/PhotoCaptureRepresentables.swift`:

```swift
import PhotosUI
import SwiftUI
import UIKit

// MARK: - Camera Picker

struct CameraPickerRepresentable: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9)
            else {
                onCancel()
                return
            }
            onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

// MARK: - Gallery Picker

struct GalleryPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self)
            else {
                onCancel()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onPick, onCancel] object, _ in
                guard let image = object as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.9)
                else {
                    DispatchQueue.main.async { onCancel() }
                    return
                }
                DispatchQueue.main.async { onPick(data) }
            }
        }
    }
}

// MARK: - Photo Processor

enum PhotoProcessor {
    /// Resize and compress image data. Returns (fullSize max 1024px JPEG 0.7, thumbnail 200px JPEG 0.6).
    static func process(_ imageData: Data) -> (fullSize: Data, thumbnail: Data)? {
        guard let image = UIImage(data: imageData) else { return nil }

        let fullSize = resized(image, maxDimension: 1024)
        guard let fullData = fullSize.jpegData(compressionQuality: 0.7) else { return nil }

        let thumb = resized(image, maxDimension: 200)
        guard let thumbData = thumb.jpegData(compressionQuality: 0.6) else { return nil }

        return (fullData, thumbData)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Packages/Features/Home/Glow/PhotoCaptureRepresentables.swift
git commit -m "feat(glow): add camera/gallery pickers + photo processor"
```

---

## Task 9: Child Features — PhotoReview, Validation, LevelUp, ChallengeAccept

**Files:**
- Create: `Packages/Features/Home/Glow/PhotoReviewFeature.swift`
- Create: `Packages/Features/Home/Glow/ValidationFeature.swift`
- Create: `Packages/Features/Home/Glow/ValidationResultView.swift`
- Create: `Packages/Features/Home/Glow/LevelUpFeature.swift`
- Create: `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift`

**Depends on:** Task 6 (endpoints), Task 7 (components)

- [ ] **Step 1: Create ChallengeAcceptFeature (reducer + view)**

Create `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift`:

```swift
import ComposableArchitecture
import SwiftUI

// MARK: - Challenge Accept Feature

@Reducer
struct ChallengeAcceptFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
    }

    enum Action: Sendable {
        case openCameraTapped
        case chooseFromGalleryTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
            case openCamera
            case openGallery
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .openCameraTapped:
                return .send(.delegate(.openCamera))
            case .chooseFromGalleryTapped:
                return .send(.delegate(.openGallery))
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Challenge Accept View

struct ChallengeAcceptView: View {
    let store: StoreOf<ChallengeAcceptFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignColors.accentWarm)
                    Text(store.challenge.challengeTitle)
                        .font(.custom("Raleway-Bold", size: 22))
                        .foregroundStyle(DesignColors.text)
                }

                Text(store.challenge.challengeDescription)
                    .font(.custom("Raleway-Regular", size: 16))
                    .foregroundStyle(DesignColors.textSecondary)
                    .lineSpacing(4)

                // Context tags
                HStack(spacing: 8) {
                    contextPill(store.challenge.cyclePhase.capitalized)
                    contextPill("Day \(store.challenge.cycleDay)")
                    energyDots(level: store.challenge.energyLevel)
                }

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(DesignColors.text)
                    ForEach(store.challenge.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(DesignColors.accentWarm)
                            Text(tip)
                                .font(.custom("Raleway-Regular", size: 14))
                                .foregroundStyle(DesignColors.textSecondary)
                        }
                    }
                }

                // Gold hint
                HStack(spacing: 8) {
                    Text("🥇")
                    Text(store.challenge.goldHint)
                        .font(.custom("Raleway-Medium", size: 14))
                        .foregroundStyle(DesignColors.accentWarm)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignColors.accentWarm.opacity(0.08))
                }

                // XP range
                Text("50–100 XP")
                    .font(.custom("Raleway-SemiBold", size: 18))
                    .foregroundStyle(DesignColors.accentWarm)
                    .frame(maxWidth: .infinity, alignment: .center)

                // CTAs
                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.send(.openCameraTapped)
                    } label: {
                        Label("Open Camera", systemImage: "camera.fill")
                            .font(.custom("Raleway-SemiBold", size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DesignColors.accentWarm)
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.send(.chooseFromGalleryTapped)
                    } label: {
                        Text("Choose from Gallery")
                            .font(.custom("Raleway-Medium", size: 15))
                            .foregroundStyle(DesignColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(DesignColors.background)
    }

    private func contextPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("Raleway-Medium", size: 12))
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule().fill(DesignColors.structure.opacity(0.15))
            }
    }

    private func energyDots(level: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= level ? DesignColors.accentWarm : DesignColors.structure.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(DesignColors.structure.opacity(0.15))
        }
    }
}
```

- [ ] **Step 2: Create PhotoReviewFeature (reducer + view)**

Create `Packages/Features/Home/Glow/PhotoReviewFeature.swift`:

```swift
import ComposableArchitecture
import SwiftUI

// MARK: - Photo Review Feature

@Reducer
struct PhotoReviewFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let imageData: Data
        let thumbnailData: Data
    }

    enum Action: Sendable {
        case submitTapped
        case retakeTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
            case submit(fullSize: Data, thumbnail: Data)
            case retake
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .submitTapped:
                return .send(.delegate(.submit(fullSize: state.imageData, thumbnail: state.thumbnailData)))
            case .retakeTapped:
                return .send(.delegate(.retake))
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Photo Review View

struct PhotoReviewView: View {
    let store: StoreOf<PhotoReviewFeature>

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Photo preview
                if let uiImage = UIImage(data: store.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom bar
                VStack(spacing: 16) {
                    Text("Aria will check if it matches")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 16) {
                        Button {
                            store.send(.retakeTapped)
                        } label: {
                            Text("Retake")
                                .font(.custom("Raleway-Medium", size: 16))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.white.opacity(0.15))
                                }
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.send(.submitTapped)
                        } label: {
                            Text("Submit")
                                .font(.custom("Raleway-SemiBold", size: 16))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(DesignColors.accentWarm)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .background(.black.opacity(0.8))
            }
        }
    }
}
```

- [ ] **Step 3: Create ValidationFeature**

Create `Packages/Features/Home/Glow/ValidationFeature.swift`:

```swift
import ComposableArchitecture
import Foundation

// MARK: - Validation Feature

@Reducer
struct ValidationFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let challenge: ChallengeSnapshot
        let photoData: Data
        let thumbnailData: Data
        var validationState: ValidationState = .loading

        enum ValidationState: Equatable, Sendable {
            case loading
            case success(ValidationResult)
            case failure(ValidationResult)
        }
    }

    struct ValidationResult: Equatable, Sendable {
        let valid: Bool
        let rating: String
        let feedback: String
        let xpMultiplier: Double
        let xpEarned: Int
    }

    enum Action: Sendable {
        case appeared
        case validationResponse(Result<ChallengeValidationResponse, Error>)
        case dismissTapped
        case tryAgainTapped
        case skipForTodayTapped
        case delegate(Delegate)
        enum Delegate: Sendable {
            case completed(
                photoData: Data, thumbnailData: Data,
                xpEarned: Int, rating: String, feedback: String
            )
            case tryAgain
            case skipForToday
        }
    }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.anonymousID) var anonymousID

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appeared:
                let challenge = state.challenge
                let photoData = state.photoData
                let thumbnailData = state.thumbnailData
                let anonId = anonymousID.getID()
                return .run { send in
                    let base64 = photoData.base64EncodedString()
                    let request = ChallengeValidationRequest(
                        anonymousId: anonId,
                        challengeType: challenge.templateId,
                        challengeDescription: challenge.challengeDescription,
                        goldHint: challenge.goldHint,
                        imageBase64: base64
                    )
                    let endpoint = Endpoint.validateChallenge(body: request)
                    do {
                        let response: ChallengeValidationResponse = try await apiClient.send(endpoint)
                        await send(.validationResponse(.success(response)))
                    } catch {
                        await send(.validationResponse(.failure(error)))
                    }
                }

            case let .validationResponse(.success(response)):
                let xp = Int(Double(GlowConstants.baseXP) * response.xpMultiplier)
                let result = ValidationResult(
                    valid: response.valid,
                    rating: response.rating,
                    feedback: response.feedback,
                    xpMultiplier: response.xpMultiplier,
                    xpEarned: xp
                )
                if response.valid {
                    state.validationState = .success(result)
                } else {
                    state.validationState = .failure(result)
                }
                return .none

            case .validationResponse(.failure):
                let result = ValidationResult(
                    valid: false,
                    rating: "bronze",
                    feedback: "Something went wrong. Try again or skip for today.",
                    xpMultiplier: 1.0,
                    xpEarned: 0
                )
                state.validationState = .failure(result)
                return .none

            case .dismissTapped:
                guard case let .success(result) = state.validationState else { return .none }
                return .send(.delegate(.completed(
                    photoData: state.photoData,
                    thumbnailData: state.thumbnailData,
                    xpEarned: result.xpEarned,
                    rating: result.rating,
                    feedback: result.feedback
                )))

            case .tryAgainTapped:
                return .send(.delegate(.tryAgain))

            case .skipForTodayTapped:
                return .send(.delegate(.skipForToday))

            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Create ValidationResultView**

Create `Packages/Features/Home/Glow/ValidationResultView.swift`:

```swift
import ComposableArchitecture
import SwiftUI

// MARK: - Validation Result View

struct ValidationResultView: View {
    let store: StoreOf<ValidationFeature>

    var body: some View {
        VStack(spacing: 0) {
            switch store.validationState {
            case .loading:
                loadingView
            case let .success(result):
                successView(result: result)
            case let .failure(result):
                failureView(result: result)
            }
        }
        .background(DesignColors.background)
        .onAppear { store.send(.appeared) }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            PulsingCircle()
                .frame(width: 60, height: 60)
            Text("Aria is checking...")
                .font(.custom("Raleway-Medium", size: 17))
                .foregroundStyle(DesignColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    // MARK: - Success

    private func successView(result: ValidationFeature.ValidationResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                // Rating badge
                RatingBadge(rating: result.rating, size: 48, animated: true)

                // Feedback
                Text(result.feedback)
                    .font(.custom("Raleway-Medium", size: 17))
                    .foregroundStyle(DesignColors.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // XP earned
                XPCountUp(targetXP: result.xpEarned)

                // Progress bar
                XPProgressBar(currentXP: result.xpEarned, animated: true)
                    .padding(.horizontal, 8)

                // Dismiss
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.send(.dismissTapped)
                } label: {
                    Text("Amazing!")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }

    // MARK: - Failure

    private func failureView(result: ValidationFeature.ValidationResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(result.feedback)
                .font(.custom("Raleway-Medium", size: 17))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(spacing: 12) {
                Button {
                    store.send(.tryAgainTapped)
                } label: {
                    Text("Try Again")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    store.send(.skipForTodayTapped)
                } label: {
                    Text("Skip for Today")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Pulsing Circle

private struct PulsingCircle: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(DesignColors.accentWarm.opacity(0.2))
            .overlay {
                Circle()
                    .fill(DesignColors.accentWarm.opacity(0.4))
                    .scaleEffect(isPulsing ? 0.6 : 0.3)
            }
            .scaleEffect(isPulsing ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - XP Count Up

private struct XPCountUp: View {
    let targetXP: Int
    @State private var displayXP: Int = 0

    var body: some View {
        Text("+\(displayXP) XP")
            .font(.custom("Raleway-Bold", size: 32))
            .foregroundStyle(DesignColors.accentWarm)
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                    displayXP = targetXP
                }
            }
    }
}
```

- [ ] **Step 5: Create LevelUpFeature (reducer + overlay view)**

Create `Packages/Features/Home/Glow/LevelUpFeature.swift`:

```swift
import ComposableArchitecture
import SwiftUI

// MARK: - Level Up Feature

@Reducer
struct LevelUpFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        let newLevel: Int
        let levelTitle: String
        let levelEmoji: String
        let unlockDescription: String
    }

    enum Action: Sendable {
        case appeared
        case dismissTapped
        case autoDismissTimerFired
        case delegate(Delegate)
        enum Delegate: Sendable {
            case dismissed
        }
    }

    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .appeared:
                return .run { send in
                    try await clock.sleep(for: .seconds(4))
                    await send(.autoDismissTimerFired)
                }

            case .dismissTapped, .autoDismissTimerFired:
                return .send(.delegate(.dismissed))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Level Up Overlay

struct LevelUpOverlay: View {
    let store: StoreOf<LevelUpFeature>
    @State private var emojiScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { store.send(.dismissTapped) }

            VStack(spacing: 16) {
                Text(store.levelEmoji)
                    .font(.system(size: 72))
                    .scaleEffect(emojiScale)

                Text("LEVEL UP!")
                    .font(.custom("Raleway-Bold", size: 28))
                    .foregroundStyle(DesignColors.accentWarm)
                    .opacity(textOpacity)

                Text("You're now a \(store.levelTitle)")
                    .font(.custom("Raleway-SemiBold", size: 20))
                    .foregroundStyle(DesignColors.text)
                    .opacity(textOpacity)

                Text(store.unlockDescription)
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundStyle(DesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                emojiScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }
            store.send(.appeared)
        }
    }
}
```

- [ ] **Step 6: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 7: Commit**

```bash
git add Packages/Features/Home/Glow/ChallengeAcceptFeature.swift Packages/Features/Home/Glow/PhotoReviewFeature.swift Packages/Features/Home/Glow/ValidationFeature.swift Packages/Features/Home/Glow/ValidationResultView.swift Packages/Features/Home/Glow/LevelUpFeature.swift
git commit -m "feat(glow): add child features — accept, photo review, validation, level up"
```

---

## Task 10: DailyChallengeFeature — Coordinator + Card View

**Files:**
- Create: `Packages/Features/Home/Glow/DailyChallengeFeature.swift`
- Create: `Packages/Features/Home/Glow/DailyChallengeCardView.swift`

**Depends on:** All previous tasks

- [ ] **Step 1: Create DailyChallengeFeature**

Create `Packages/Features/Home/Glow/DailyChallengeFeature.swift`:

```swift
import ComposableArchitecture
import Foundation

// MARK: - Photo Capture State

enum PhotoCaptureState: Equatable, Sendable, Identifiable {
    case camera
    case gallery

    var id: String {
        switch self {
        case .camera: "camera"
        case .gallery: "gallery"
        }
    }
}

enum PhotoCaptureAction: Sendable {
    case photoCaptured(Data)
    case cancelled
}

// MARK: - Daily Challenge Feature

@Reducer
struct DailyChallengeFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        var challenge: ChallengeSnapshot?
        var profile: GlowProfileSnapshot?
        var challengeState: ChallengeState = .idle

        enum ChallengeState: Equatable, Sendable {
            case idle
            case available
            case skipped
            case completed
        }

        @Presents var acceptSheet: ChallengeAcceptFeature.State?
        @Presents var photoCapture: PhotoCaptureState?
        @Presents var photoReview: PhotoReviewFeature.State?
        @Presents var validation: ValidationFeature.State?
        @Presents var levelUp: LevelUpFeature.State?
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)

        case selectChallenge(phase: String, energyLevel: Int)
        case challengeLoaded(ChallengeSnapshot?)
        case challengeSelected(ChallengeSnapshot)
        case doItTapped
        case skipTapped
        case maybeLaterTapped

        case acceptSheet(PresentationAction<ChallengeAcceptFeature.Action>)
        case photoCapture(PresentationAction<PhotoCaptureAction>)
        case photoReview(PresentationAction<PhotoReviewFeature.Action>)
        case validation(PresentationAction<ValidationFeature.Action>)
        case levelUp(PresentationAction<LevelUpFeature.Action>)

        case photoCaptured(Data)

        case delegate(Delegate)
        enum Delegate: Sendable {
            case challengeStateChanged(ChallengeSnapshot?)
        }
    }

    @Dependency(\.glowLocal) var glowLocal

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // MARK: - Challenge Selection

            case let .selectChallenge(phase, energyLevel):
                return .run { send in
                    // Check if already have today's challenge
                    if let existing = try await glowLocal.getTodayChallenge() {
                        await send(.challengeLoaded(existing))
                        return
                    }
                    // Select new challenge
                    let recentIds = try await glowLocal.getRecentCompletedTemplateIds(14)
                    let templates = ChallengeTemplatePool.templates
                    guard let template = ChallengeSelector.select(
                        phase: phase,
                        energyLevel: energyLevel,
                        recentTemplateIds: recentIds,
                        templates: templates
                    ) else {
                        await send(.challengeLoaded(nil))
                        return
                    }
                    let snapshot = ChallengeSnapshot(
                        id: UUID(),
                        date: Date(),
                        templateId: template.id,
                        challengeCategory: template.category,
                        challengeTitle: template.title,
                        challengeDescription: template.description,
                        tips: template.tips,
                        goldHint: template.goldHint,
                        validationPrompt: template.validationPrompt,
                        cyclePhase: phase,
                        cycleDay: 0,
                        energyLevel: energyLevel,
                        status: .available,
                        completedAt: nil,
                        photoThumbnail: nil,
                        validationRating: nil,
                        validationFeedback: nil,
                        xpEarned: 0
                    )
                    try await glowLocal.saveChallenge(snapshot)
                    await send(.challengeSelected(snapshot))
                }

            case let .challengeLoaded(snapshot):
                state.challenge = snapshot
                if let snapshot {
                    state.challengeState = ChallengeSnapshot.ChallengeStatus(rawValue: snapshot.status.rawValue) == .completed
                        ? .completed
                        : ChallengeSnapshot.ChallengeStatus(rawValue: snapshot.status.rawValue) == .skipped
                            ? .skipped
                            : .available
                }
                // Load profile
                return .merge(
                    .send(.delegate(.challengeStateChanged(snapshot))),
                    .run { [glowLocal] send in
                        // Preload profile for XP display
                        _ = try? await glowLocal.getProfile()
                    }
                )

            case let .challengeSelected(snapshot):
                state.challenge = snapshot
                state.challengeState = .available
                return .send(.delegate(.challengeStateChanged(snapshot)))

            // MARK: - User Actions

            case .doItTapped:
                guard let challenge = state.challenge else { return .none }
                state.acceptSheet = ChallengeAcceptFeature.State(challenge: challenge)
                return .none

            case .skipTapped:
                guard let challenge = state.challenge else { return .none }
                state.challengeState = .skipped
                var updated = challenge
                updated.status = .skipped
                state.challenge = updated
                return .merge(
                    .send(.delegate(.challengeStateChanged(updated))),
                    .run { [glowLocal] _ in
                        try await glowLocal.skipChallenge(challenge.id)
                    }
                )

            case .maybeLaterTapped:
                state.challengeState = .available
                if var challenge = state.challenge {
                    challenge.status = .available
                    state.challenge = challenge
                    return .send(.delegate(.challengeStateChanged(challenge)))
                }
                return .none

            // MARK: - Accept Sheet Delegates

            case .acceptSheet(.presented(.delegate(.openCamera))):
                state.acceptSheet = nil
                state.photoCapture = .camera
                return .none

            case .acceptSheet(.presented(.delegate(.openGallery))):
                state.acceptSheet = nil
                state.photoCapture = .gallery
                return .none

            case .acceptSheet:
                return .none

            // MARK: - Photo Capture

            case let .photoCapture(.presented(.photoCaptured(data))):
                state.photoCapture = nil
                guard let processed = PhotoProcessor.process(data) else { return .none }
                state.photoReview = PhotoReviewFeature.State(
                    imageData: processed.fullSize,
                    thumbnailData: processed.thumbnail
                )
                return .none

            case .photoCapture(.presented(.cancelled)):
                state.photoCapture = nil
                return .none

            case .photoCapture:
                return .none

            // MARK: - Photo Review Delegates

            case let .photoReview(.presented(.delegate(.submit(fullSize, thumbnail)))):
                state.photoReview = nil
                guard let challenge = state.challenge else { return .none }
                state.validation = ValidationFeature.State(
                    challenge: challenge,
                    photoData: fullSize,
                    thumbnailData: thumbnail
                )
                return .none

            case .photoReview(.presented(.delegate(.retake))):
                state.photoReview = nil
                state.photoCapture = .camera
                return .none

            case .photoReview:
                return .none

            // MARK: - Validation Delegates

            case let .validation(.presented(.delegate(.completed(photoData, thumbnailData, xpEarned, rating, feedback)))):
                state.validation = nil
                guard var challenge = state.challenge else { return .none }

                challenge.status = .completed
                challenge.completedAt = Date()
                challenge.validationRating = rating
                challenge.validationFeedback = feedback
                challenge.xpEarned = xpEarned
                challenge.photoThumbnail = thumbnailData
                state.challenge = challenge
                state.challengeState = .completed

                let challengeId = challenge.id
                return .run { [glowLocal] send in
                    try await glowLocal.completeChallenge(
                        challengeId, photoData, thumbnailData, rating, feedback, xpEarned
                    )
                    let (previous, current) = try await glowLocal.addXP(xpEarned, rating)

                    // Check level up
                    if current.currentLevel > previous.currentLevel {
                        let levelInfo = GlowConstants.levelFor(xp: current.totalXP)
                        let unlock = GlowConstants.unlockDescriptions[current.currentLevel] ?? ""
                        await send(.levelUp(.presented(.appeared)))
                        // We need to set state first — done via challengeStateChanged
                    }

                    await send(.delegate(.challengeStateChanged(challenge)))
                }

            case .validation(.presented(.delegate(.tryAgain))):
                state.validation = nil
                state.photoCapture = .camera
                return .none

            case .validation(.presented(.delegate(.skipForToday))):
                state.validation = nil
                return .send(.skipTapped)

            case .validation:
                return .none

            // MARK: - Level Up

            case .levelUp(.presented(.delegate(.dismissed))):
                state.levelUp = nil
                return .none

            case .levelUp:
                return .none

            case .photoCaptured:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$acceptSheet, action: \.acceptSheet) { ChallengeAcceptFeature() }
        .ifLet(\.$photoReview, action: \.photoReview) { PhotoReviewFeature() }
        .ifLet(\.$validation, action: \.validation) { ValidationFeature() }
        .ifLet(\.$levelUp, action: \.levelUp) { LevelUpFeature() }
    }
}
```

- [ ] **Step 2: Create DailyChallengeCardView**

Create `Packages/Features/Home/Glow/DailyChallengeCardView.swift`:

```swift
import SwiftUI

// MARK: - Daily Challenge Card View

struct DailyChallengeCardView: View {
    let challenge: ChallengeSnapshot
    let onDoIt: () -> Void
    let onSkip: () -> Void
    let onMaybeLater: () -> Void

    var body: some View {
        switch challenge.status {
        case .available: availableState
        case .completed: completedState
        case .skipped: skippedState
        }
    }

    // MARK: - Available

    private var availableState: some View {
        VStack(alignment: .leading) {
            // Challenge pill
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Challenge")
                    .font(.custom("Raleway-SemiBold", size: 12))
            }
            .foregroundStyle(DesignColors.accentWarm)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(DesignColors.accentWarm.opacity(0.1)) }

            Spacer()

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Bold", size: 24))
                .foregroundStyle(DesignColors.text)
                .lineSpacing(4)

            Text(challenge.challengeDescription)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundStyle(DesignColors.textSecondary)
                .lineSpacing(3)
                .lineLimit(2)

            // Tags
            HStack(spacing: 6) {
                tagPill(challenge.cyclePhase.capitalized)
                tagPill("Day \(challenge.cycleDay)")
            }
            .padding(.top, 4)

            Spacer().frame(height: 16)

            // CTAs
            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDoIt()
                } label: {
                    Text("Do It")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(height: 320)
        .cardBackground()
    }

    // MARK: - Completed

    private var completedState: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 12) {
                // Thumbnail
                if let thumbData = challenge.photoThumbnail,
                   let uiImage = UIImage(data: thumbData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let rating = challenge.validationRating {
                        RatingBadge(rating: rating, size: 24)
                    }
                    Text("+\(challenge.xpEarned) XP")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .foregroundStyle(DesignColors.accentWarm)
                }
            }

            Spacer()

            if let feedback = challenge.validationFeedback {
                Text(feedback)
                    .font(.custom("Raleway-Medium", size: 16))
                    .foregroundStyle(DesignColors.text)
                    .lineSpacing(4)
                    .lineLimit(3)
            }

            Text(challenge.challengeTitle)
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundStyle(DesignColors.textSecondary)
        }
        .padding(32)
        .frame(height: 320)
        .cardBackground()
    }

    // MARK: - Skipped

    private var skippedState: some View {
        VStack {
            Spacer()

            Text("Your challenge is here whenever you're ready")
                .font(.custom("Raleway-Medium", size: 17))
                .foregroundStyle(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 24)

            Button {
                onMaybeLater()
            } label: {
                Text("Maybe Later")
                    .font(.custom("Raleway-Medium", size: 15))
                    .foregroundStyle(DesignColors.accentWarm)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(32)
        .frame(height: 320)
        .cardBackground()
    }

    // MARK: - Helpers

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("Raleway-Medium", size: 11))
            .foregroundStyle(DesignColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background { Capsule().fill(DesignColors.structure.opacity(0.15)) }
    }
}

// MARK: - Card Background Modifier

private extension View {
    func cardBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DesignColors.background, Color(hex: 0xF5E8E2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [DesignColors.structure.opacity(0.4), DesignColors.accentWarm.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusL, style: .continuous))
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 4: Commit**

```bash
git add Packages/Features/Home/Glow/DailyChallengeFeature.swift Packages/Features/Home/Glow/DailyChallengeCardView.swift
git commit -m "feat(glow): add DailyChallengeFeature coordinator + card view"
```

---

## Task 11: CardStackFeature Integration

**Files:**
- Modify: `Packages/Features/Home/CardStackFeature.swift`

**Depends on:** Task 10

- [ ] **Step 1: Add challenge state + delegate actions to CardStackFeature**

In `CardStackFeature.State` (after line 19, after `public var currentDay: Int?`), add:

```swift
        /// Active challenge for the Do card — passed from TodayFeature
        public var challengeSnapshot: ChallengeSnapshot?
```

In `CardStackFeature.Action.Delegate` (after line 48, after `case openCheckIn`), add:

```swift
            case challengeDoItTapped
            case challengeSkipTapped
            case challengeMaybeLaterTapped
```

- [ ] **Step 2: Update actionTapped handler for .challenge type**

In the reducer (around line 149), change:

```swift
                case .quickCheck, .challenge:
                    return .none
```

to:

```swift
                case .quickCheck:
                    return .none
                case .challenge:
                    // Handled by DailyChallengeCardView buttons via delegate
                    return .none
```

- [ ] **Step 3: Update DailyCardView to use DailyChallengeCardView when challenge is active**

In `CardStackView` (around line 247), change the `DailyCardView` usage inside the `ForEach` to conditionally use `DailyChallengeCardView`:

Replace the `DailyCardView(...)` block with:

```swift
                    if item.card.cardType == .do, let challenge = store.challengeSnapshot {
                        DailyChallengeCardView(
                            challenge: challenge,
                            onDoIt: { store.send(.delegate(.challengeDoItTapped)) },
                            onSkip: { store.send(.delegate(.challengeSkipTapped)) },
                            onMaybeLater: { store.send(.delegate(.challengeMaybeLaterTapped)) }
                        )
                        .padding(.horizontal, AppLayout.horizontalPadding)
                    } else {
                        DailyCardView(
                            card: item.card,
                            displayDay: store.currentDay,
                            onAction: { store.send(.actionTapped(item.card)) },
                            onCheckIn: { store.send(.delegate(.openCheckIn)) }
                        )
                        .padding(.horizontal, AppLayout.horizontalPadding)
                    }
```

Note: The shadow, scale, offset, rotation, and gesture modifiers that follow remain unchanged — they apply to whichever card view is rendered.

- [ ] **Step 4: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

- [ ] **Step 5: Commit**

```bash
git add Packages/Features/Home/CardStackFeature.swift
git commit -m "feat(glow): integrate challenge snapshot into CardStackFeature"
```

---

## Task 12: TodayFeature Integration — Wire Everything Together

**Files:**
- Modify: `Packages/Features/Home/TodayFeature.swift`

**Depends on:** Task 10, Task 11

- [ ] **Step 1: Add DailyChallengeFeature state to TodayFeature**

In `TodayFeature.State` (after line 95, after `public var cardStackState`), add:

```swift
        // Daily Glow challenge
        public var dailyChallengeState: DailyChallengeFeature.State = DailyChallengeFeature.State()
```

- [ ] **Step 2: Add actions to TodayFeature**

In `TodayFeature.Action` (after `case cardStack(CardStackFeature.Action)` around line 108), add:

```swift
        case dailyChallenge(DailyChallengeFeature.Action)
```

- [ ] **Step 3: Add Scope + routing in TodayFeature.body**

In the reducer `body` (inside `var body: some ReducerOf<Self>`), add the Scope for DailyChallengeFeature. After the existing CardStackFeature Scope (search for `Scope(state: \.cardStackState, action: \.cardStack)`), add:

```swift
        Scope(state: \.dailyChallengeState, action: \.dailyChallenge) {
            DailyChallengeFeature()
        }
```

- [ ] **Step 4: Route phaseResolved to DailyChallengeFeature**

In the `phaseResolved` handler (around line 524), change:

```swift
            case let .phaseResolved(phase, day):
                return .send(.cardStack(.loadCards(phase, day)))
```

to:

```swift
            case let .phaseResolved(phase, day):
                let energy = state.dashboard?.today?.scores?.energy ?? 3
                return .merge(
                    .send(.cardStack(.loadCards(phase, day))),
                    .send(.dailyChallenge(.selectChallenge(phase: phase.rawValue, energyLevel: energy)))
                )
```

- [ ] **Step 5: Route CardStack challenge delegates to DailyChallengeFeature**

In the `case .cardStack(.delegate(...))` handler, add cases for the new delegates:

```swift
            case .cardStack(.delegate(.challengeDoItTapped)):
                return .send(.dailyChallenge(.doItTapped))

            case .cardStack(.delegate(.challengeSkipTapped)):
                return .send(.dailyChallenge(.skipTapped))

            case .cardStack(.delegate(.challengeMaybeLaterTapped)):
                return .send(.dailyChallenge(.maybeLaterTapped))
```

- [ ] **Step 6: Handle DailyChallengeFeature delegate — update CardStack snapshot**

Add a handler for the challenge state change:

```swift
            case let .dailyChallenge(.delegate(.challengeStateChanged(snapshot))):
                state.cardStackState.challengeSnapshot = snapshot
                return .none
```

And a catch-all for other dailyChallenge actions:

```swift
            case .dailyChallenge:
                return .none
```

- [ ] **Step 7: Present DailyChallengeFeature sheets in TodayView**

In the `TodayView` (or wherever the TodayFeature view is defined), add sheet/cover presentations scoped to `dailyChallengeState`. Find where other sheets are presented (e.g., `.sheet` for checkIn) and add:

```swift
        // Challenge accept sheet
        .sheet(
            item: $store.scope(
                state: \.dailyChallengeState.acceptSheet,
                action: \.dailyChallenge.acceptSheet
            )
        ) { acceptStore in
            ChallengeAcceptView(store: acceptStore)
                .presentationDetents([.medium])
        }
        // Photo capture (camera or gallery)
        .fullScreenCover(
            item: $store.scope(
                state: \.dailyChallengeState.photoCapture,
                action: \.dailyChallenge.photoCapture
            )
        ) { captureStore in
            // The store state is PhotoCaptureState (.camera or .gallery)
            // We need to handle this at the view level
            PhotoCaptureWrapperView(store: captureStore)
        }
        // Photo review
        .fullScreenCover(
            item: $store.scope(
                state: \.dailyChallengeState.photoReview,
                action: \.dailyChallenge.photoReview
            )
        ) { reviewStore in
            PhotoReviewView(store: reviewStore)
        }
        // Validation result
        .sheet(
            item: $store.scope(
                state: \.dailyChallengeState.validation,
                action: \.dailyChallenge.validation
            )
        ) { validationStore in
            ValidationResultView(store: validationStore)
                .presentationDetents([.medium])
        }
        // Level up overlay
        .overlay {
            if let levelUpStore = store.scope(
                state: \.dailyChallengeState.levelUp,
                action: \.dailyChallenge.levelUp
            ) {
                LevelUpOverlay(store: levelUpStore)
            }
        }
```

Note: `PhotoCaptureWrapperView` needs to be a small wrapper that reads `PhotoCaptureState` and presents the appropriate UIKit picker. Add this in `PhotoCaptureRepresentables.swift` or inline in `DailyChallengeFeature.swift`:

```swift
struct PhotoCaptureWrapperView: View {
    let store: StoreOf</* PhotoCapture reducer */>
    // This will need adjustment based on how TCA scopes @Presents enums
    // The implementer should use the actual TCA pattern for enum-based @Presents
}
```

**IMPORTANT NOTE FOR IMPLEMENTER:** The `@Presents var photoCapture: PhotoCaptureState?` is an enum, not a reducer state. TCA's `.ifLet` doesn't compose enum-based presentation the same way. The implementer may need to convert this to a simpler `var isShowingCamera: Bool` + `var isShowingGallery: Bool` pattern, or handle the UIViewControllerRepresentable presentation manually in the view layer without TCA scoping. The key constraint is: dismiss the camera/gallery → call `store.send(.photoCaptured(data))` on the parent `DailyChallengeFeature`.

A simpler approach: use `@State` in the view for camera/gallery presentation, driven by `DailyChallengeFeature.State` flags:

```swift
// In DailyChallengeFeature.State, replace @Presents var photoCapture with:
var isShowingCamera: Bool = false
var isShowingGallery: Bool = false
```

Then in the view:
```swift
.fullScreenCover(isPresented: $store.dailyChallengeState.isShowingCamera) {
    CameraPickerRepresentable(
        onCapture: { data in store.send(.dailyChallenge(.photoCaptured(data))) },
        onCancel: { store.send(.dailyChallenge(.photoCaptureCancel)) }
    )
}
```

The implementer should choose whichever pattern compiles cleanly with TCA's binding infrastructure.

- [ ] **Step 8: Verify it compiles**

Run: `xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -5`

This is the most likely step to have compilation issues. Fix any type mismatches, missing cases in switch statements, or TCA scoping issues before proceeding.

- [ ] **Step 9: Commit**

```bash
git add Packages/Features/Home/TodayFeature.swift
git commit -m "feat(glow): wire DailyChallengeFeature into TodayFeature"
```

---

## Task 13: Expand challenge_templates.json to 80 Templates

**Files:**
- Modify: `Packages/Core/CycleEngine/Resources/challenge_templates.json`

- [ ] **Step 1: Expand to 80 templates**

Generate ~80 challenge templates following this distribution:

| Category | Count | Primary Phases | Energy Range |
|----------|-------|---------------|--------------|
| social | 14 | ovulatory, follicular | 3-5 |
| self_care | 14 | menstrual, luteal | 1-3 |
| creative | 14 | follicular, ovulatory | 2-5 |
| movement | 13 | follicular, ovulatory | 3-5 |
| mindfulness | 13 | luteal, menstrual | 1-4 |
| nutrition | 12 | all phases | 2-5 |

Each template must have:
- Unique `id` in format `{category}_{phase}_{number}` (e.g., `social_ovulatory_03`)
- `phases` array with 1-3 phases where the activity fits
- `energyMin`/`energyMax` range (1-5)
- Clear, actionable `title` (2-6 words)
- `description` (one sentence, warm tone)
- `tips` array with exactly 3 strings
- `goldHint` (what "above and beyond" looks like)
- `validationPrompt` (instructions for AI photo validator)

Validate the JSON is parseable:

```bash
python3 -c "import json; json.load(open('Packages/Core/CycleEngine/Resources/challenge_templates.json')); print('Valid JSON')"
```

- [ ] **Step 2: Commit**

```bash
git add Packages/Core/CycleEngine/Resources/challenge_templates.json
git commit -m "feat(glow): expand challenge templates to 80 entries"
```

---

## Task 14: XcodeGen + Final Build Verification

**Files:**
- Possibly modify: `project.yml`

- [ ] **Step 1: Check XcodeGen picks up new Glow/ directory and Resources/**

Run:

```bash
cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate 2>&1
```

Check if sources in `Packages/Features/Home/Glow/` and resources in `Packages/Core/CycleEngine/Resources/` are included. If `xcodegen generate` succeeds but build fails with "file not found" for Glow files, add the source path to `project.yml`.

Check `project.yml` for source globs — if it uses recursive patterns like `Packages/**/*.swift`, the new subdirectory should be auto-included.

- [ ] **Step 2: Full build**

```bash
xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Fix any remaining build errors**

Address all compiler errors. Common issues:
- Missing `import` statements (all files need `import Foundation` or `import SwiftUI` at minimum; no internal module imports)
- TCA scoping issues with `@Presents` enum states
- Missing `Sendable` conformances
- Switch statement exhaustiveness

- [ ] **Step 4: Commit any fixes**

```bash
git add -A && git commit -m "fix(glow): resolve build errors from integration"
```

---

## Dependency Graph

```
Task 1 (GlowConstants) ─────────────┐
Task 2 (SwiftData Models) ───────────┤
Task 3 (Snapshots) ──────────────────┼──→ Task 4 (GlowLocalClient)
                                     │
Task 5 (Templates + Selector) ───────┤
Task 6 (Endpoints) ──────────────────┤
Task 7 (UI Components) ─────────────┤
Task 8 (Photo Capture) ─────────────┤
                                     │
                                     └──→ Task 9 (Child Features)
                                              │
                                              └──→ Task 10 (Coordinator + Card View)
                                                      │
                                                      ├──→ Task 11 (CardStack Integration)
                                                      │
                                                      └──→ Task 12 (TodayFeature Integration)
                                                              │
Task 13 (80 Templates) ─────────────────────────────────────┘
                                                              │
                                                     Task 14 (Final Build)
```

**Parallelizable groups:**
- Group A (independent): Tasks 1, 2, 5, 6, 7, 8
- Group B (after 1+2): Task 3, then Task 4
- Group C (after all core): Task 9
- Group D (after 9): Task 10
- Group E (after 10): Tasks 11, 12 (sequential)
- Group F (after 12): Tasks 13, 14

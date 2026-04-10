# Recap Notification Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken UserDefaults+in-memory recap banner system with a single SwiftData source of truth using the existing `CycleRecapRecord.isViewed` field.

**Architecture:** The existing `isViewed: Bool` on `CycleRecapRecord` becomes the sole source of truth. Banner visibility is derived by querying SwiftData for any record where `isViewed == false`. All UserDefaults keys (`NewRecapCycleKey`, `NewRecapMonthName`, `LastDismissedRecapKey`) and in-memory state (`unviewedRecapMonth`) are removed. The TCA reducer queries SwiftData directly through a new method on `MenstrualLocalClient`.

**Tech Stack:** SwiftData, TCA (The Composable Architecture), Swift 6

---

### Task 1: Add SwiftData Query Methods to MenstrualLocalClient

**Files:**
- Modify: `Packages/Core/Persistence/MenstrualLocalClient.swift:9-46` (client definition)
- Modify: `Packages/Core/Persistence/MenstrualLocalClient.swift:65+` (live implementation)

- [ ] **Step 1: Add two new closures to the client struct**

In `MenstrualLocalClient` struct (after line 45), add:

```swift
/// Returns the month name of the most recent unviewed recap, or nil.
public var unviewedRecapMonth: @Sendable () async throws -> String?

/// Marks all unviewed recaps as viewed.
public var markAllRecapsViewed: @Sendable () async throws -> Void
```

- [ ] **Step 2: Implement live values**

In the `live()` function (inside the `MenstrualLocalClient(` initializer), add:

```swift
unviewedRecapMonth: {
    let container = CycleDataStore.shared
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<CycleRecapRecord>(
        predicate: #Predicate { $0.isViewed == false },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    guard let record = try? context.fetch(descriptor).first else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    if let date = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: record.cycleKey)
    }() {
        return formatter.string(from: date)
    }
    return nil
},
markAllRecapsViewed: {
    let container = CycleDataStore.shared
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<CycleRecapRecord>(
        predicate: #Predicate { $0.isViewed == false }
    )
    let unviewed = (try? context.fetch(descriptor)) ?? []
    for record in unviewed {
        record.isViewed = true
    }
    try? context.save()
}
```

- [ ] **Step 3: Add mock/test values**

Find the `mock()` function and add:

```swift
unviewedRecapMonth: { nil },
markAllRecapsViewed: { }
```

- [ ] **Step 4: Build to verify compilation**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Packages/Core/Persistence/MenstrualLocalClient.swift
git commit -m "feat: add unviewedRecapMonth and markAllRecapsViewed to MenstrualLocalClient"
```

---

### Task 2: Remove UserDefaults Logic from CycleRecapGeneration

**Files:**
- Modify: `Packages/Features/Home/CycleRecapGeneration.swift:71-116` (remove UserDefaults functions)
- Modify: `Packages/Features/Home/CycleRecapGeneration.swift:48-77` (update cacheRecap)
- Modify: `Packages/Features/Home/CycleRecapGeneration.swift:345-369` (update preGenerateAll)

- [ ] **Step 1: Remove UserDefaults helper functions**

Delete lines 79-116 entirely (the `// MARK: Viewed State` section):
- `newRecapKey` constant
- `setNewRecap(cycleKey:monthName:)`
- `markRecapViewed(cycleStart:)`
- `isRecapDismissed(cycleKey:)`
- `newRecapMonthName()`
- `monthNameFormatter`
- `unviewedRecapMonth()`

- [ ] **Step 2: Remove UserDefaults call from cacheRecap**

In `cacheRecap(_:cycleStart:)` (line 48), remove lines 71-76 (the `setNewRecap` call after saving to SwiftData). The function should end after `try? context.save()` on line 70.

```swift
static func cacheRecap(_ data: RecapData, cycleStart: Date) {
    let container = CycleDataStore.shared
    let context = ModelContext(container)
    let key = dateKey(cycleStart)

    let descriptor = FetchDescriptor<CycleRecapRecord>(
        predicate: #Predicate { $0.cycleKey == key }
    )
    if let existing = try? context.fetch(descriptor) {
        for r in existing { context.delete(r) }
    }

    let record = CycleRecapRecord(
        cycleKey: key,
        chapterOverview: data.overviewText,
        chapterBody: data.bodyText,
        chapterMind: data.mindText,
        chapterPattern: data.patternText,
        headline: data.headline,
        cycleVibe: data.cycleVibe
    )
    context.insert(record)
    try? context.save()
}
```

- [ ] **Step 3: Simplify preGenerateAll**

Replace the `preGenerateAll` function (lines 345-369). Remove all UserDefaults banner checks. It only needs to generate missing recaps:

```swift
static func preGenerateAll(summaries: [JourneyCycleSummary]) async {
    for summary in summaries {
        guard !summary.isCurrentCycle else {
            print("[RecapGen] skip current \(summary.startDate)")
            continue
        }
        if CycleJourneyFeature.loadCachedRecap(cycleStart: summary.startDate) != nil {
            continue
        }
        print("[RecapGen] fetching AI for \(summary.startDate)...")
        if let recap = await CycleJourneyFeature.fetchRecapAI(summary: summary, allSummaries: summaries) {
            CycleJourneyFeature.cacheRecap(recap, cycleStart: summary.startDate)
            print("[RecapGen] saved \(summary.startDate)")
        } else {
            print("[RecapGen] AI failed for \(summary.startDate)")
        }
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -20`
Expected: Compilation errors in TodayFeature (references to removed functions). That's expected — Task 3 fixes them.

- [ ] **Step 5: Commit**

```bash
git add Packages/Features/Home/CycleRecapGeneration.swift
git commit -m "refactor: remove UserDefaults recap banner logic, single source is SwiftData isViewed"
```

---

### Task 3: Rewire TodayFeature to Use SwiftData Query

**Files:**
- Modify: `Packages/Features/Home/TodayFeature.swift:93-94` (remove state)
- Modify: `Packages/Features/Home/TodayFeature.swift:134-136` (remove actions)
- Modify: `Packages/Features/Home/TodayFeature.swift:480-483` (fix backgroundSyncPeriod)
- Modify: `Packages/Features/Home/TodayFeature.swift:508-547` (replace handlers)
- Modify: `Packages/Features/Home/TodayFeature.swift:688-694` (update view)

- [ ] **Step 1: Replace in-memory state with computed query**

Remove `unviewedRecapMonth` from State (line 94).

Add a new state property:

```swift
// Recap banner — driven by SwiftData query
public var recapBannerMonth: String?
```

- [ ] **Step 2: Replace actions**

Remove these actions (lines 134-136):
- `case checkRecapBanner`
- `case recapBannerUpdated(String?)`
- `case generateMissingRecaps`

Add these actions:

```swift
case refreshRecapBanner
case recapBannerLoaded(String?)
case generateMissingRecaps
```

- [ ] **Step 3: Rewrite the reducer handlers**

Replace the `checkRecapBanner` and `recapBannerUpdated` handlers (lines 508-515) with:

```swift
case .refreshRecapBanner:
    return .run { [menstrualLocal] send in
        let month = try? await menstrualLocal.unviewedRecapMonth()
        await send(.recapBannerLoaded(month))
    }

case .recapBannerLoaded(let month):
    state.recapBannerMonth = month
    return .none
```

- [ ] **Step 4: Update generateMissingRecaps handler**

Replace the `generateMissingRecaps` handler (lines 517-547) with:

```swift
case .generateMissingRecaps:
    return .run { [menstrualLocal] send in
        let data = try await menstrualLocal.getJourneyData()
        let summaries = CycleJourneyEngine.buildSummaries(
            inputs: data.records,
            reports: data.reports,
            profileAvgCycleLength: data.profileAvgCycleLength,
            profileAvgBleedingDays: data.profileAvgBleedingDays,
            currentCycleStartDate: data.currentCycleStartDate
        )
        for summary in summaries where !summary.isCurrentCycle {
            let hasCached = CycleJourneyFeature.loadCachedRecap(cycleStart: summary.startDate) != nil
            if !hasCached {
                if let recap = await CycleJourneyFeature.fetchRecapAI(summary: summary, allSummaries: summaries) {
                    CycleJourneyFeature.cacheRecap(recap, cycleStart: summary.startDate)
                }
            }
        }
        // After generation, refresh banner from SwiftData
        await send(.refreshRecapBanner)
    }
    .cancellable(id: CancelID.recapGeneration, cancelInFlight: true)
```

- [ ] **Step 5: Fix backgroundSyncPeriod handler**

In `backgroundSyncPeriod` (line 480-483), remove:

```swift
state.unviewedRecapMonth = nil
CycleJourneyFeature.markRecapViewed(cycleStart: Date())
```

Replace with:

```swift
state.recapBannerMonth = nil
```

(The banner will refresh naturally after sync completes → `generateMissingRecaps` → `refreshRecapBanner`)

- [ ] **Step 6: Update all dispatch sites**

Replace `.send(.checkRecapBanner)` at line 313 with `.send(.refreshRecapBanner)`.

- [ ] **Step 7: Update the view**

In TodayView (lines 688-694), replace `store.unviewedRecapMonth` with `store.recapBannerMonth`:

```swift
RecapReadyBanner(
    monthName: store.recapBannerMonth,
    onTap: { store.send(.delegate(.openCycleJourney)) }
)
.padding(.horizontal, AppLayout.horizontalPadding)
.padding(.top, AppLayout.spacingM)
.animation(.easeOut(duration: 0.4), value: store.recapBannerMonth)
```

- [ ] **Step 8: Build to verify compilation**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add Packages/Features/Home/TodayFeature.swift
git commit -m "refactor: TodayFeature recap banner reads from SwiftData instead of UserDefaults"
```

---

### Task 4: Mark Recaps Viewed on Banner Tap and Journey Open

**Files:**
- Modify: `Packages/Features/Home/HomeFeature.swift:211-220` (add markViewed on journey open)
- Modify: `Packages/Features/Home/CycleJourneyFeature.swift:63-69` (mark viewed on appear)
- Modify: `Packages/Features/Home/CycleJourneyFeature.swift:136-148` (remove old markRecapViewed)

- [ ] **Step 1: Add menstrualLocal dependency to CycleJourneyFeature**

Check if `CycleJourneyFeature` already has `@Dependency(\.menstrualLocal) var menstrualLocal`. If not, add it.

- [ ] **Step 2: Mark all recaps viewed on Journey onAppear**

In the `onAppear` handler (line 63), add after `state.isLoading = true`:

```swift
case .onAppear:
    guard !state.hasAppeared else { return .none }
    state.hasAppeared = true
    state.isLoading = true
    return .merge(
        .run { [menstrualLocal] send in
            await send(.journeyLoaded(Result { try await menstrualLocal.getJourneyData() }))
        },
        .run { [menstrualLocal] _ in
            try? await menstrualLocal.markAllRecapsViewed()
        }
    )
```

- [ ] **Step 3: Remove old markRecapViewed call from recapLoaded**

In `.recapLoaded` handler (line 136-148), remove the `.run` effect that calls `CycleJourneyFeature.markRecapViewed(cycleStart:)`. Change it to just return `.none`:

```swift
case .recapLoaded(let data):
    state.recap?.isLoading = false
    state.recap?.headline = data.headline
    state.recap?.cycleVibe = data.cycleVibe
    state.recap?.overviewText = data.overviewText
    state.recap?.bodyText = data.bodyText
    state.recap?.mindText = data.mindText
    state.recap?.patternText = data.patternText
    return .none
```

Note: The `let startDate = state.recap?.summary.startDate` and `guard let startDate` lines are also removed since they were only needed for the old markRecapViewed call.

- [ ] **Step 4: Update HomeFeature dismiss to refresh banner**

In HomeFeature (line 218-220), the dismiss handler already sends `.today(.checkRecapBanner)`. Update it to the new action name:

```swift
case .cycleJourney(.delegate(.dismiss)):
    state.isCycleJourneyVisible = false
    return .send(.today(.refreshRecapBanner))
```

- [ ] **Step 5: Also mark viewed and refresh banner when opening Journey from banner tap**

In HomeFeature (line 211-216), add a markAllRecapsViewed effect:

```swift
case .today(.delegate(.openCycleJourney)):
    state.cycleJourneyState = CycleJourneyFeature.State()
    state.cycleJourneyState.cycleContext = state.todayState.cycle
    state.cycleJourneyState.menstrualStatus = state.todayState.menstrualStatus
    state.isCycleJourneyVisible = true
    // Clear banner immediately for snappy UI
    state.todayState.recapBannerMonth = nil
    return .none
```

- [ ] **Step 6: Build to verify compilation**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Packages/Features/Home/CycleJourneyFeature.swift Packages/Features/Home/HomeFeature.swift
git commit -m "feat: mark recaps viewed on journey open, clear banner immediately on tap"
```

---

### Task 5: Clean Up Stale UserDefaults on First Launch

**Files:**
- Modify: `Packages/Features/Home/CycleRecapGeneration.swift` (add one-time cleanup)

- [ ] **Step 1: Add a cleanup function**

Add to `CycleRecapGeneration.swift` (in the `CycleJourneyFeature` extension):

```swift
/// One-time cleanup: remove legacy UserDefaults keys from old recap banner system.
static func cleanupLegacyRecapDefaults() {
    let keys = ["NewRecapCycleKey", "NewRecapMonthName", "LastDismissedRecapKey"]
    for key in keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
```

- [ ] **Step 2: Call cleanup on app launch**

In `TodayFeature`, inside the existing `calendarEntriesLoaded` success path (near line 313 where `refreshRecapBanner` is sent), add a one-time call:

```swift
// In the .calendarEntriesLoaded(.success) handler, add to the merge:
.run { _ in CycleJourneyFeature.cleanupLegacyRecapDefaults() }
```

Or alternatively, call it in the `generateMissingRecaps` handler before generation starts.

- [ ] **Step 3: Build and verify**

Run: `cd /Users/mihai/Developer/cycle.app-frontend-swift && xcodegen generate && xcodebuild -project CycleApp.xcodeproj -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16' build -skipPackagePluginValidation 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Packages/Features/Home/CycleRecapGeneration.swift Packages/Features/Home/TodayFeature.swift
git commit -m "chore: clean up legacy UserDefaults recap keys on launch"
```

---

## Summary of Changes

| File | Change |
|------|--------|
| `MenstrualLocalClient.swift` | Add `unviewedRecapMonth` and `markAllRecapsViewed` |
| `CycleRecapGeneration.swift` | Remove all UserDefaults functions, simplify cacheRecap and preGenerateAll, add legacy cleanup |
| `TodayFeature.swift` | Replace `unviewedRecapMonth` with `recapBannerMonth`, replace actions, query SwiftData |
| `CycleJourneyFeature.swift` | Mark recaps viewed on onAppear, remove old markRecapViewed call |
| `HomeFeature.swift` | Clear banner immediately on journey open, update action names |
| `CycleRecapRecord.swift` | No changes — `isViewed: Bool = false` already exists |

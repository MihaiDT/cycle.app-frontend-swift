# Challenge Detail Screen Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cramped `.medium`-detent `ChallengeAcceptView` with a full-screen, Tolan × Apple-style detail screen. Every element answers a user question; no decoration for its own sake.

**Architecture:** Three self-contained changes — add a new design token, add TDD'd display extensions on `ChallengeSnapshot`, and rewrite the view + switch container in one atomic commit. The `ChallengeAcceptFeature` reducer stays untouched; dismissal uses SwiftUI's `@Environment(\.dismiss)` which propagates cleanly through the TCA `$store.scope` binding on `.fullScreenCover(item:)`.

**Tech Stack:** SwiftUI, The Composable Architecture (TCA) 1.17+, Swift Testing, Swift 6 strict concurrency, XcodeGen, iOS 17+, Raleway font family (Black / SemiBold / Medium / Bold bundled).

**Design spec:** [`../specs/2026-04-13-challenge-detail-redesign.md`](../specs/2026-04-13-challenge-detail-redesign.md)

---

## File Structure

| Change | Path | What it holds |
|---|---|---|
| Modify | `Packages/Core/DesignSystem/DesignColors.swift` | New `cardWarm` token (`#F7F2E8`) |
| Create | `CycleAppTests/ChallengeSnapshotTests.swift` | Unit tests for the three display helpers |
| Modify | `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift` | Full rewrite of `ChallengeAcceptView` + display extension on `ChallengeSnapshot` |
| Modify | `Packages/Features/Home/TodayFeature.swift` (lines 1136-1147) | `.sheet(item:)` → `.fullScreenCover(item:)`, strip 4 presentation modifiers |

The reducer, actions, delegate, and downstream screens (`PhotoReviewFeature`, `ValidationFeature`, `ValidationResultView`) are **untouched**.

Run `xcodegen generate` once after Task 2 adds the new test file — it updates `CycleApp.xcodeproj/project.pbxproj` so the test target picks up `ChallengeSnapshotTests.swift`. No xcodegen run needed for Tasks 1 or 3 since they only modify existing files.

---

## Task 1: Add `DesignColors.cardWarm` token

**Files:**
- Modify: `Packages/Core/DesignSystem/DesignColors.swift:6-10`

- [ ] **Step 1: Add the token constant**

Open `Packages/Core/DesignSystem/DesignColors.swift`. Find the `// MARK: - Backgrounds` section (lines 6-9). Add one line after `backgroundElegant`:

```swift
    // MARK: - Backgrounds
    public static let background = Color(hex: 0xFDFCF7)  // Ivory Whisper - fundal
    public static let backgroundElegant = Color(hex: 0xFDFCF7)  // Champagne Silk - eleganta, confort
    public static let cardWarm = Color(hex: 0xF7F2E8)  // Warm card surface — stat boxes & how-to card
```

- [ ] **Step 2: Build to verify nothing breaks**

```bash
cd /Users/mihai/Developer/cycle.app-frontend-swift
xcodebuild -project CycleApp.xcodeproj -scheme CycleApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build -skipPackagePluginValidation -quiet
```

Expected output: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Packages/Core/DesignSystem/DesignColors.swift
git commit -m "$(cat <<'EOF'
feat(design-system): add cardWarm token for warm card surfaces

#F7F2E8 — 2% warmer than background. Used by the upcoming
challenge detail redesign for stat boxes and the how-to card.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: TDD display extensions on `ChallengeSnapshot`

**Files:**
- Create: `CycleAppTests/ChallengeSnapshotTests.swift`
- Modify: `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift` (append extension at end of file)

- [ ] **Step 1: Write the failing tests**

Create `CycleAppTests/ChallengeSnapshotTests.swift`:

```swift
@testable import CycleApp
import Foundation
import Testing

struct ChallengeSnapshotDisplayTests {
    // Helper to build a minimal ChallengeSnapshot for tests
    private func make(
        category: String = "social",
        energyLevel: Int = 5
    ) -> ChallengeSnapshot {
        ChallengeSnapshot(
            id: UUID(),
            date: Date(),
            templateId: "test",
            challengeCategory: category,
            challengeTitle: "Test",
            challengeDescription: "Test description",
            tips: [],
            goldHint: "",
            validationPrompt: "",
            cyclePhase: "luteal",
            cycleDay: 0,
            energyLevel: energyLevel,
            status: .available,
            completedAt: nil,
            photoThumbnail: nil,
            validationRating: nil,
            validationFeedback: nil,
            xpEarned: 0
        )
    }

    // MARK: - effortDisplay (energyLevel is 1-10)

    @Test
    func testEffortDisplayGentle() {
        #expect(make(energyLevel: 1).effortDisplay == "Gentle")
        #expect(make(energyLevel: 2).effortDisplay == "Gentle")
        #expect(make(energyLevel: 3).effortDisplay == "Gentle")
    }

    @Test
    func testEffortDisplayModerate() {
        #expect(make(energyLevel: 4).effortDisplay == "Moderate")
        #expect(make(energyLevel: 5).effortDisplay == "Moderate")
        #expect(make(energyLevel: 6).effortDisplay == "Moderate")
    }

    @Test
    func testEffortDisplayActive() {
        #expect(make(energyLevel: 7).effortDisplay == "Active")
        #expect(make(energyLevel: 10).effortDisplay == "Active")
    }

    // MARK: - themeDisplay

    @Test
    func testThemeDisplayKnownCategories() {
        #expect(make(category: "social").themeDisplay == "Social")
        #expect(make(category: "mindfulness").themeDisplay == "Mindful")
        #expect(make(category: "movement").themeDisplay == "Movement")
        #expect(make(category: "creative").themeDisplay == "Creative")
        #expect(make(category: "nutrition").themeDisplay == "Nutrition")
        #expect(make(category: "self_care").themeDisplay == "Self care")
    }

    @Test
    func testThemeDisplayCaseInsensitive() {
        #expect(make(category: "SOCIAL").themeDisplay == "Social")
        #expect(make(category: "Self_Care").themeDisplay == "Self care")
    }

    @Test
    func testThemeDisplayFallback() {
        #expect(make(category: "new_unknown").themeDisplay == "New_unknown")
    }

    // MARK: - durationDisplay

    @Test
    func testDurationDisplayByCategory() {
        #expect(make(category: "creative").durationDisplay == "15 min")
        #expect(make(category: "movement").durationDisplay == "10 min")
        #expect(make(category: "social").durationDisplay == "5 min")
        #expect(make(category: "mindfulness").durationDisplay == "5 min")
        #expect(make(category: "self_care").durationDisplay == "5 min")
        #expect(make(category: "nutrition").durationDisplay == "5 min")
    }

    @Test
    func testDurationDisplayUnknownDefaultsToFiveMin() {
        #expect(make(category: "unknown").durationDisplay == "5 min")
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project**

```bash
cd /Users/mihai/Developer/cycle.app-frontend-swift
xcodegen generate
```

Expected output: `Created project at CycleApp.xcodeproj`.

- [ ] **Step 3: Run tests — expect failure**

```bash
xcodebuild test \
  -project CycleApp.xcodeproj \
  -scheme CycleApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -skipPackagePluginValidation \
  -only-testing:CycleAppTests/ChallengeSnapshotDisplayTests \
  -quiet 2>&1 | tail -40
```

Expected: compile errors referencing undefined `effortDisplay`, `themeDisplay`, and `durationDisplay` properties on `ChallengeSnapshot`. The build fails before any test runs — that's fine, it proves the tests are asking for something that doesn't exist yet.

- [ ] **Step 4: Implement the extension**

Open `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift`. At the very bottom of the file, after the closing `}` of the `ChallengeAcceptView` struct (line 151), append:

```swift

// MARK: - ChallengeSnapshot Display Helpers

extension ChallengeSnapshot {
    /// Short label for the stat row. `energyLevel` is a 1–10 scale.
    var effortDisplay: String {
        switch energyLevel {
        case ...3:  return "Gentle"
        case 4...6: return "Moderate"
        default:    return "Active"
        }
    }

    /// Human-readable category label for the stat row.
    var themeDisplay: String {
        switch challengeCategory.lowercased() {
        case "self_care":   return "Self care"
        case "mindfulness": return "Mindful"
        case "movement":    return "Movement"
        case "creative":    return "Creative"
        case "nutrition":   return "Nutrition"
        case "social":      return "Social"
        default:            return challengeCategory.capitalized
        }
    }

    /// Time estimate for the stat row. Local heuristic until backend adds an estimatedMinutes field.
    var durationDisplay: String {
        switch challengeCategory.lowercased() {
        case "creative": return "15 min"
        case "movement": return "10 min"
        default:         return "5 min"
        }
    }
}
```

- [ ] **Step 5: Run tests — expect pass**

```bash
xcodebuild test \
  -project CycleApp.xcodeproj \
  -scheme CycleApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -skipPackagePluginValidation \
  -only-testing:CycleAppTests/ChallengeSnapshotDisplayTests \
  -quiet 2>&1 | tail -30
```

Expected output: `** TEST SUCCEEDED **` and 9 passing tests (`testEffortDisplayGentle`, `testEffortDisplayModerate`, `testEffortDisplayActive`, `testThemeDisplayKnownCategories`, `testThemeDisplayCaseInsensitive`, `testThemeDisplayFallback`, `testDurationDisplayByCategory`, `testDurationDisplayUnknownDefaultsToFiveMin`).

- [ ] **Step 6: Commit**

```bash
git add CycleAppTests/ChallengeSnapshotTests.swift \
        CycleApp.xcodeproj/project.pbxproj \
        Packages/Features/Home/Glow/ChallengeAcceptFeature.swift
git commit -m "$(cat <<'EOF'
feat(glow): display extensions on ChallengeSnapshot

Adds effortDisplay (Gentle/Moderate/Active from 1–10 energy),
themeDisplay (human-readable labels for the 6 known categories),
and durationDisplay (5/10/15 min heuristic by category). Unit
tests cover all known categories plus fallbacks.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Rewrite `ChallengeAcceptView` + switch `TodayFeature` to full-screen cover

**Files:**
- Modify: `Packages/Features/Home/TodayFeature.swift:1135-1147`
- Modify: `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift:42-151`

This task changes two files that must land together: the new view expects to be presented full-screen, and the full-screen cover expects a view that has its own close button. They ship as one atomic commit.

- [ ] **Step 1: Switch the container in `TodayFeature.swift`**

Open `Packages/Features/Home/TodayFeature.swift`. Find the `DailyGlowPresentations` view modifier body, specifically lines 1135-1147 (the "Daily Glow — accept sheet" block).

Current code:

```swift
            // Daily Glow — accept sheet
            .sheet(
                item: $store.scope(
                    state: \.dailyChallengeState.acceptSheet,
                    action: \.dailyChallenge.acceptSheet
                )
            ) { acceptStore in
                ChallengeAcceptView(store: acceptStore)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(AppLayout.cornerRadiusL)
                    .presentationBackground(DesignColors.background)
            }
```

Replace with:

```swift
            // Daily Glow — accept (full-screen)
            .fullScreenCover(
                item: $store.scope(
                    state: \.dailyChallengeState.acceptSheet,
                    action: \.dailyChallenge.acceptSheet
                )
            ) { acceptStore in
                ChallengeAcceptView(store: acceptStore)
            }
```

Leave the other two modifiers in the same `DailyGlowPresentations` block (`.fullScreenCover` for `photoReview` at lines 1149-1156 and `.sheet` for `validation` at lines 1158+) **unchanged**.

- [ ] **Step 2: Rewrite `ChallengeAcceptView` in `ChallengeAcceptFeature.swift`**

Open `Packages/Features/Home/Glow/ChallengeAcceptFeature.swift`. Delete the entire existing `ChallengeAcceptView` struct (from `// MARK: - Challenge Accept View` on line 40 through the final `}` of the struct on line 151). Leave the `@Reducer struct ChallengeAcceptFeature` block (lines 1-38) and the `ChallengeSnapshot` display extension (added in Task 2, at the bottom of the file) **untouched**.

In place of the deleted struct, paste this new implementation:

```swift
// MARK: - Challenge Accept View

struct ChallengeAcceptView: View {
    let store: StoreOf<ChallengeAcceptFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    phaseAnchor
                    titleBlock
                    whySubtitle
                    statRow
                    howCard
                    Spacer(minLength: 170)
                }
            }

            ctaCluster
        }
        .background(DesignColors.background.ignoresSafeArea())
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignColors.text)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DesignColors.text.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Phase anchor

    private var phaseAnchor: some View {
        Text("Today · \(store.challenge.cyclePhase) phase")
            .font(.custom("Raleway-Bold", size: 11))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(DesignColors.accentWarm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
            .accessibilityLabel("Today, \(store.challenge.cyclePhase) phase")
    }

    // MARK: - Title block

    private var titleBlock: some View {
        Text(store.challenge.challengeTitle)
            .font(.custom("Raleway-Black", size: 44))
            .tracking(-0.9)
            .lineSpacing(-6)
            .foregroundStyle(DesignColors.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Why subtitle

    private var whySubtitle: some View {
        Text(store.challenge.challengeDescription)
            .font(.custom("Raleway-Medium", size: 17))
            .foregroundStyle(DesignColors.textPrincipal)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 10) {
            statBox(value: store.challenge.durationDisplay, label: "Time")
            statBox(value: store.challenge.effortDisplay, label: "Effort")
            statBox(value: store.challenge.themeDisplay, label: "Theme")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Takes \(store.challenge.durationDisplay), " +
            "effort \(store.challenge.effortDisplay), " +
            "theme \(store.challenge.themeDisplay)"
        )
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 7) {
            Text(value)
                .font(.custom("Raleway-Black", size: 20))
                .tracking(-0.3)
                .foregroundStyle(DesignColors.text)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(.custom("Raleway-Bold", size: 9))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignColors.cardWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DesignColors.text.opacity(0.07), lineWidth: 1)
                )
        )
    }

    // MARK: - How card

    private var howCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How to do it")
                .font(.custom("Raleway-Black", size: 10))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DesignColors.accentWarm)
                .padding(.bottom, 14)

            ForEach(Array(store.challenge.tips.enumerated()), id: \.offset) { index, tip in
                tipRow(number: index + 1, text: tip, isFirst: index == 0)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignColors.cardWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DesignColors.text.opacity(0.07), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func tipRow(number: Int, text: String, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(DesignColors.text.opacity(0.08))
                    .frame(height: 1)
            }
            HStack(alignment: .top, spacing: 14) {
                Text("\(number)")
                    .font(.custom("Raleway-Black", size: 11))
                    .foregroundStyle(DesignColors.background)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DesignColors.text))
                Text(text)
                    .font(.custom("Raleway-Medium", size: 15))
                    .foregroundStyle(DesignColors.textPrincipal)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }

    // MARK: - CTA cluster

    private var ctaCluster: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DesignColors.background.opacity(0), DesignColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.send(.openCameraTapped)
                } label: {
                    HStack {
                        Text("Start challenge")
                            .font(.custom("Raleway-Black", size: 17))
                            .tracking(-0.2)
                            .foregroundStyle(DesignColors.background)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DesignColors.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(DesignColors.background))
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 26)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(DesignColors.text)
                    )
                    .shadow(color: DesignColors.text.opacity(0.22), radius: 20, x: 0, y: 8)
                    .shadow(color: DesignColors.text.opacity(0.12), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start challenge")
                .accessibilityHint("Opens the camera to take a photo of your challenge")

                Button {
                    store.send(.chooseFromGalleryTapped)
                } label: {
                    Text("Or choose from gallery")
                        .font(.custom("Raleway-SemiBold", size: 13))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Choose an existing photo instead of taking a new one")

                Text("Earns 50–100 glow on completion")
                    .font(.custom("Raleway-SemiBold", size: 11))
                    .foregroundStyle(DesignColors.textSecondary)
                    .padding(.top, 4)
                    .accessibilityLabel("Earns 50 to 100 glow points on completion")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(DesignColors.background)
        }
    }
}
```

- [ ] **Step 3: Build to verify compile**

```bash
cd /Users/mihai/Developer/cycle.app-frontend-swift
xcodebuild -project CycleApp.xcodeproj -scheme CycleApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build -skipPackagePluginValidation -quiet 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`. Swift 6 strict concurrency is on — any `Sendable` complaint indicates a regression, fix it before moving on.

- [ ] **Step 4: Manual QA in simulator**

```bash
./scripts/dev.sh
```

This builds + installs on the iPhone 16 simulator and launches the app. Walk through this checklist and confirm each item before moving on:

1. Navigate Home → tap the Daily Glow card
2. The screen appears **full-screen** (not a sheet with a grabber, no rounded top corners peeking home behind it)
3. Top-right `✕` button dismisses back to Home cleanly
4. Title renders with tight line breaks — for the sample `"Smile at three people"` the 3-line break is visually intentional, not accidental
5. Phase anchor reads `"TODAY · LUTEAL PHASE"` (or whatever phase is active)
6. Subtitle (description) wraps cleanly below the title
7. Stat row shows three text-only boxes: duration / effort / theme, each with a big value and small uppercase label
8. How-to card shows numbered tips (1, 2, 3…) with dividers between them
9. Scroll works: content scrolls behind the pinned CTA cluster with a clean cream fade
10. "Start challenge" button opens the camera (existing PhotoCapture flow)
11. "Or choose from gallery" opens the photo picker
12. VoiceOver (Settings → Accessibility → VoiceOver, or Simulator → Features → Toggle VoiceOver) reads:
    - Close button as "Close"
    - Title as a header
    - Phase anchor as "Today, luteal phase"
    - Stat row as one combined label
    - Each tip as "Step N, <text>"
    - CTA with the "Opens the camera…" hint

If any item fails, fix inline before the commit.

- [ ] **Step 5: Commit**

```bash
git add Packages/Features/Home/TodayFeature.swift \
        Packages/Features/Home/Glow/ChallengeAcceptFeature.swift
git commit -m "$(cat <<'EOF'
feat(glow): redesign challenge detail as full-screen Tolan×Apple view

Replaces the cramped .medium sheet with a full-screen cover.
Typography-led hierarchy: 44pt Raleway-Black title, stat row
(time/effort/theme), how-to card with numbered steps, pinned
cocoa CTA with a cream arrow badge, quiet reward footer.

Dismissal uses @Environment(\.dismiss) which propagates through
TCA's $store.scope binding — no reducer change needed. View-only
rewrite: reducer, actions, delegate, and downstream screens are
untouched.

Removes: "Day 0" label (sidesteps upstream cycleDay=0 bug),
5-dot energyLevel rating, 🥇 medal emoji, "XP" terminology
(now "glow" to match the feature name).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage** — every requirement from `2026-04-13-challenge-detail-redesign.md` maps to a task:

| Spec section | Task |
|---|---|
| Container: `.fullScreenCover(item:)`, strip presentation modifiers | Task 3, Step 1 |
| Phase anchor, title, why subtitle, stat row, how card, CTA cluster | Task 3, Step 2 |
| Typography table (Raleway-Black 44pt / Medium 17pt / Bold 11pt / etc.) | Task 3, Step 2 code |
| Colors (`background`, `text`, `textPrincipal`, `textSecondary`, `accentWarm`, `cardWarm`) | Tasks 1 + 3 |
| `cardWarm = #F7F2E8` new token | Task 1 |
| `effortDisplay` / `themeDisplay` / `durationDisplay` extensions | Task 2 |
| Phase anchor never displays `cycleDay` | Task 3 (no `cycleDay` reference in view) |
| Why subtitle reuses `challengeDescription` | Task 3 (`store.challenge.challengeDescription`) |
| "XP" → "glow" rename in reward footer | Task 3 |
| `openCameraTapped` / `chooseFromGalleryTapped` reused | Task 3 |
| Accessibility labels on all elements | Task 3 |
| TCA reducer, actions, delegate untouched | Confirmed — Tasks 1-3 touch only view code, extension code, and one file with a presentation-modifier swap |

**Placeholder scan** — no `TBD`, no `"add error handling"`, no `"similar to Task N"`, all code blocks are complete.

**Type consistency** — `effortDisplay` / `themeDisplay` / `durationDisplay` names match between Task 2 (tests), Task 2 (extension), and Task 3 (view usage). `cardWarm` matches between Task 1 and Task 3.

**Scope check** — one feature, one screen, four file touches, three atomic commits. Appropriate for a single plan.
